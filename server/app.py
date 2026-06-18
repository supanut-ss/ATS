"""
app.py — Flask webhook server + REST API for XAUUSD MT5 Trading System
Endpoints:
  POST /webhook                 — TradingView alert receiver
  GET  /api/status              — Server & MT5 connection status
  GET  /api/account             — Account balance/equity info
  GET  /api/price               — Live XAUUSD bid/ask/spread
  GET  /api/positions           — Open positions
  GET  /api/history             — Closed trade history
  GET  /api/risk                — Risk manager status
  POST /api/trade               — Manual trade (BUY/SELL)
  POST /api/close/<ticket>      — Close specific position
  POST /api/close-all           — Close all positions
  POST /api/modify/<ticket>     — Modify SL/TP
  POST /api/connect             — Connect to MT5
  POST /api/disconnect          — Disconnect from MT5
"""

import logging
import json
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS

from config import FLASK_HOST, FLASK_PORT, FLASK_DEBUG, WEBHOOK_SECRET
from mt5_bridge import MT5Bridge
from risk_manager import RiskManager
from signal_handler import SignalHandler

# ──────────────────────────────────────────────
# Logging Setup
# ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("trading_bot.log", encoding="utf-8"),
    ]
)
logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# Flask App
# ──────────────────────────────────────────────
app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "*"}, r"/webhook": {"origins": "*"}})

bridge = MT5Bridge()
risk   = RiskManager()
sig_h  = SignalHandler()

# Webhook log (in-memory ring buffer, last 50)
webhook_log: list[dict] = []


def _log_webhook(data: dict, result: dict, error: str = None):
    entry = {
        "time":   datetime.utcnow().isoformat() + "Z",
        "data":   data,
        "result": result,
        "error":  error,
    }
    webhook_log.append(entry)
    if len(webhook_log) > 50:
        webhook_log.pop(0)


# ──────────────────────────────────────────────
# Webhook Endpoint (TradingView → MT5)
# ──────────────────────────────────────────────
@app.route("/webhook", methods=["POST"])
def webhook():
    try:
        data = request.get_json(force=True, silent=True) or {}
        logger.info(f"Webhook received: {json.dumps(data)}")

        # Parse & validate signal
        signal = sig_h.parse(data)
        action = signal["action"]

        if action in ("BUY", "SELL"):
            # Risk check
            check = risk.validate_open(action)
            if not check["ok"]:
                _log_webhook(data, {}, error=check["reason"])
                return jsonify({"ok": False, "error": check["reason"]}), 200

            result = bridge.open_trade(
                action=action,
                sl=signal["sl"],
                tp=signal["tp"],
                comment=signal["comment"],
            )

        elif action == "CLOSE":
            ticket = signal.get("ticket")
            if not ticket:
                # If no ticket, close the latest open position
                positions = bridge.get_positions()
                if not positions:
                    result = {"ok": False, "error": "No open positions to close"}
                else:
                    ticket = positions[-1]["ticket"]
                    result = bridge.close_position(ticket)
            else:
                result = bridge.close_position(ticket)

        elif action == "CLOSE_ALL":
            result = bridge.close_all_positions()

        elif action == "MODIFY":
            ticket = signal.get("ticket")
            if not ticket:
                return jsonify({"ok": False, "error": "ticket required for MODIFY"}), 400
            result = bridge.modify_position(
                ticket=ticket,
                sl=signal["sl"] or None,
                tp=signal["tp"] or None,
            )
        else:
            result = {"ok": False, "error": f"Unknown action: {action}"}

        _log_webhook(data, result)
        return jsonify(result), 200

    except PermissionError as e:
        logger.warning(f"Webhook auth failed: {e}")
        _log_webhook(data if 'data' in dir() else {}, {}, error=str(e))
        return jsonify({"ok": False, "error": "Unauthorized"}), 401

    except (ValueError, KeyError) as e:
        logger.error(f"Webhook parse error: {e}")
        _log_webhook(data if 'data' in dir() else {}, {}, error=str(e))
        return jsonify({"ok": False, "error": str(e)}), 400

    except Exception as e:
        logger.exception(f"Webhook unhandled error: {e}")
        return jsonify({"ok": False, "error": str(e)}), 500


# ──────────────────────────────────────────────
# API: Status
# ──────────────────────────────────────────────
@app.route("/api/status", methods=["GET"])
def api_status():
    return jsonify({
        "server":      "online",
        "mt5_connected": bridge.is_connected(),
        "time":        datetime.utcnow().isoformat() + "Z",
        "webhook_log": webhook_log[-10:],
    })


# ──────────────────────────────────────────────
# API: MT5 Connect / Disconnect
# ──────────────────────────────────────────────
@app.route("/api/connect", methods=["POST"])
def api_connect():
    result = bridge.connect()
    return jsonify(result)


@app.route("/api/disconnect", methods=["POST"])
def api_disconnect():
    bridge.disconnect()
    return jsonify({"ok": True, "message": "MT5 disconnected"})


# ──────────────────────────────────────────────
# API: Account / Price / Positions / History
# ──────────────────────────────────────────────
@app.route("/api/account", methods=["GET"])
def api_account():
    return jsonify(bridge.get_account_info())


@app.route("/api/price", methods=["GET"])
def api_price():
    return jsonify(bridge.get_price())


@app.route("/api/positions", methods=["GET"])
def api_positions():
    return jsonify(bridge.get_positions())


@app.route("/api/history", methods=["GET"])
def api_history():
    days = int(request.args.get("days", 7))
    return jsonify(bridge.get_history(days=days))


@app.route("/api/risk", methods=["GET"])
def api_risk():
    return jsonify(risk.get_risk_status())


# ──────────────────────────────────────────────
# API: Manual Trade Controls
# ──────────────────────────────────────────────
@app.route("/api/trade", methods=["POST"])
def api_trade():
    try:
        data = request.get_json(force=True, silent=True) or {}
        action = str(data.get("action", "")).upper()
        if action not in ("BUY", "SELL"):
            return jsonify({"ok": False, "error": "action must be BUY or SELL"}), 400

        check = risk.validate_open(action)
        if not check["ok"]:
            return jsonify({"ok": False, "error": check["reason"]}), 200

        result = bridge.open_trade(
            action=action,
            sl=float(data.get("sl", 0)),
            tp=float(data.get("tp", 0)),
            comment="Manual",
        )
        return jsonify(result)
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/api/close/<int:ticket>", methods=["POST"])
def api_close(ticket: int):
    result = bridge.close_position(ticket)
    return jsonify(result)


@app.route("/api/close-all", methods=["POST"])
def api_close_all():
    result = bridge.close_all_positions()
    return jsonify(result)


@app.route("/api/modify/<int:ticket>", methods=["POST"])
def api_modify(ticket: int):
    try:
        data = request.get_json(force=True, silent=True) or {}
        sl = float(data["sl"]) if data.get("sl") else None
        tp = float(data["tp"]) if data.get("tp") else None
        result = bridge.modify_position(ticket=ticket, sl=sl, tp=tp)
        return jsonify(result)
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


# ──────────────────────────────────────────────
# Entry Point
# ──────────────────────────────────────────────
if __name__ == "__main__":
    logger.info("═" * 60)
    logger.info("  XAUUSD Trading Bot — Flask Server Starting")
    logger.info("═" * 60)

    # Auto-connect to MT5 on startup
    result = bridge.connect()
    if result["ok"]:
        logger.info(f"  MT5 Connected ✓ | Account #{result['account']} | {result['server']}")
    else:
        logger.warning(f"  MT5 Connect failed: {result['error']}")
        logger.warning("  → You can connect manually via POST /api/connect")

    logger.info(f"  Server running at http://{FLASK_HOST}:{FLASK_PORT}")
    logger.info(f"  Webhook URL: http://localhost:{FLASK_PORT}/webhook")
    logger.info("═" * 60)

    app.run(host=FLASK_HOST, port=FLASK_PORT, debug=FLASK_DEBUG, use_reloader=False)
