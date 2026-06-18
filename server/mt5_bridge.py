"""
mt5_bridge.py — MetaTrader5 connection and trade execution layer
Broker: Exness | Symbol: XAUUSD
"""

import MetaTrader5 as mt5
import logging
from datetime import datetime, timezone
from config import (
    SYMBOL, FIXED_LOT, MAGIC_NUMBER, SLIPPAGE,
    MT5_LOGIN, MT5_PASSWORD, MT5_SERVER
)

logger = logging.getLogger(__name__)


class MT5Bridge:
    def __init__(self):
        self._connected = False

    # ──────────────────────────────────────────────
    # Connection
    # ──────────────────────────────────────────────
    def connect(self) -> dict:
        """Initialize and login to MT5 terminal."""
        if not mt5.initialize():
            err = mt5.last_error()
            logger.error(f"MT5 initialize() failed: {err}")
            return {"ok": False, "error": f"initialize() failed: {err}"}

        # If login credentials provided, authorize
        if MT5_LOGIN and MT5_PASSWORD:
            if not mt5.login(MT5_LOGIN, password=MT5_PASSWORD, server=MT5_SERVER):
                err = mt5.last_error()
                logger.error(f"MT5 login failed: {err}")
                mt5.shutdown()
                return {"ok": False, "error": f"login() failed: {err}"}

        self._connected = True
        acc = mt5.account_info()
        logger.info(f"MT5 Connected — Account #{acc.login} | Server: {acc.server}")
        return {"ok": True, "account": acc.login, "server": acc.server}

    def disconnect(self):
        mt5.shutdown()
        self._connected = False
        logger.info("MT5 disconnected.")

    def is_connected(self) -> bool:
        if not self._connected:
            return False
        info = mt5.terminal_info()
        return info is not None and info.connected

    # ──────────────────────────────────────────────
    # Account Info
    # ──────────────────────────────────────────────
    def get_account_info(self) -> dict:
        acc = mt5.account_info()
        if acc is None:
            return {"error": "Cannot retrieve account info"}
        return {
            "login":       acc.login,
            "server":      acc.server,
            "name":        acc.name,
            "currency":    acc.currency,
            "balance":     round(acc.balance, 2),
            "equity":      round(acc.equity, 2),
            "margin":      round(acc.margin, 2),
            "free_margin": round(acc.margin_free, 2),
            "profit":      round(acc.profit, 2),
            "leverage":    acc.leverage,
        }

    # ──────────────────────────────────────────────
    # Symbol Price
    # ──────────────────────────────────────────────
    def get_price(self) -> dict:
        tick = mt5.symbol_info_tick(SYMBOL)
        if tick is None:
            return {"error": f"Cannot get tick for {SYMBOL}"}
        sym = mt5.symbol_info(SYMBOL)
        return {
            "symbol":     SYMBOL,
            "bid":        round(tick.bid, 2),
            "ask":        round(tick.ask, 2),
            "spread":     round((tick.ask - tick.bid) * 10, 1),  # in pips (XAUUSD: 1 pip=0.1)
            "time":       datetime.fromtimestamp(tick.time, tz=timezone.utc).isoformat(),
            "point":      sym.point if sym else 0.01,
        }

    # ──────────────────────────────────────────────
    # Open Positions
    # ──────────────────────────────────────────────
    def get_positions(self) -> list:
        positions = mt5.positions_get(symbol=SYMBOL)
        if positions is None:
            return []
        result = []
        for p in positions:
            tick = mt5.symbol_info_tick(SYMBOL)
            current_price = tick.bid if p.type == mt5.ORDER_TYPE_BUY else tick.ask
            result.append({
                "ticket":       p.ticket,
                "type":         "BUY" if p.type == mt5.ORDER_TYPE_BUY else "SELL",
                "volume":       p.volume,
                "open_price":   round(p.price_open, 2),
                "current_price": round(current_price, 2),
                "sl":           round(p.sl, 2),
                "tp":           round(p.tp, 2),
                "profit":       round(p.profit, 2),
                "swap":         round(p.swap, 2),
                "open_time":    datetime.fromtimestamp(p.time, tz=timezone.utc).isoformat(),
                "comment":      p.comment,
                "magic":        p.magic,
            })
        return result

    def count_positions(self) -> int:
        positions = mt5.positions_get(symbol=SYMBOL, magic=MAGIC_NUMBER)
        return len(positions) if positions else 0

    # ──────────────────────────────────────────────
    # Trade History
    # ──────────────────────────────────────────────
    def get_history(self, days: int = 7) -> list:
        from_date = datetime(2000, 1, 1, tzinfo=timezone.utc)
        to_date = datetime.now(tz=timezone.utc)
        deals = mt5.history_deals_get(from_date, to_date)
        if deals is None:
            return []

        history = []
        for d in sorted(deals, key=lambda x: x.time, reverse=True)[:100]:
            if d.symbol != SYMBOL:
                continue
            history.append({
                "ticket":    d.ticket,
                "order":     d.order,
                "type":      "BUY" if d.type == mt5.DEAL_TYPE_BUY else ("SELL" if d.type == mt5.DEAL_TYPE_SELL else "BALANCE"),
                "volume":    d.volume,
                "price":     round(d.price, 2),
                "profit":    round(d.profit, 2),
                "swap":      round(d.swap, 2),
                "fee":       round(d.fee, 2),
                "comment":   d.comment,
                "time":      datetime.fromtimestamp(d.time, tz=timezone.utc).isoformat(),
            })
        return history

    # ──────────────────────────────────────────────
    # Open Trade
    # ──────────────────────────────────────────────
    def open_trade(self, action: str, sl: float = 0.0, tp: float = 0.0, comment: str = "Bot") -> dict:
        """
        Open a BUY or SELL market order on XAUUSD.
        sl / tp should be in price (e.g. 2320.50), 0 = no SL/TP
        """
        tick = mt5.symbol_info_tick(SYMBOL)
        if tick is None:
            return {"ok": False, "error": f"Cannot get tick for {SYMBOL}"}

        sym = mt5.symbol_info(SYMBOL)
        if sym is None or not sym.visible:
            mt5.symbol_select(SYMBOL, True)

        if action.upper() == "BUY":
            order_type = mt5.ORDER_TYPE_BUY
            price = tick.ask
        elif action.upper() == "SELL":
            order_type = mt5.ORDER_TYPE_SELL
            price = tick.bid
        else:
            return {"ok": False, "error": f"Unknown action: {action}"}

        request = {
            "action":       mt5.TRADE_ACTION_DEAL,
            "symbol":       SYMBOL,
            "volume":       FIXED_LOT,
            "type":         order_type,
            "price":        price,
            "sl":           round(sl, 2) if sl else 0.0,
            "tp":           round(tp, 2) if tp else 0.0,
            "deviation":    SLIPPAGE,
            "magic":        MAGIC_NUMBER,
            "comment":      comment[:31],  # MT5 comment max 31 chars
            "type_time":    mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }

        result = mt5.order_send(request)
        if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
            err = mt5.last_error()
            retcode = result.retcode if result else -1
            logger.error(f"order_send failed: retcode={retcode}, error={err}")
            return {
                "ok":      False,
                "retcode": retcode,
                "error":   str(result.comment) if result else str(err),
            }

        logger.info(f"Order opened: {action} {FIXED_LOT} lot @ {result.price} | ticket={result.order}")
        return {
            "ok":     True,
            "ticket": result.order,
            "price":  round(result.price, 2),
            "volume": FIXED_LOT,
            "action": action.upper(),
        }

    # ──────────────────────────────────────────────
    # Close Position
    # ──────────────────────────────────────────────
    def close_position(self, ticket: int) -> dict:
        pos = mt5.positions_get(ticket=ticket)
        if not pos:
            return {"ok": False, "error": f"Position {ticket} not found"}
        p = pos[0]

        tick = mt5.symbol_info_tick(SYMBOL)
        if tick is None:
            return {"ok": False, "error": "Cannot get tick"}

        close_type = mt5.ORDER_TYPE_SELL if p.type == mt5.ORDER_TYPE_BUY else mt5.ORDER_TYPE_BUY
        close_price = tick.bid if p.type == mt5.ORDER_TYPE_BUY else tick.ask

        request = {
            "action":       mt5.TRADE_ACTION_DEAL,
            "symbol":       SYMBOL,
            "volume":       p.volume,
            "type":         close_type,
            "position":     ticket,
            "price":        close_price,
            "deviation":    SLIPPAGE,
            "magic":        MAGIC_NUMBER,
            "comment":      "Bot Close",
            "type_time":    mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        result = mt5.order_send(request)
        if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
            err = mt5.last_error()
            retcode = result.retcode if result else -1
            return {"ok": False, "retcode": retcode, "error": str(result.comment) if result else str(err)}

        logger.info(f"Position closed: ticket={ticket} @ {result.price}")
        return {"ok": True, "ticket": ticket, "close_price": round(result.price, 2)}

    def close_all_positions(self) -> dict:
        positions = mt5.positions_get(symbol=SYMBOL)
        if not positions:
            return {"ok": True, "closed": 0}
        results = []
        for p in positions:
            r = self.close_position(p.ticket)
            results.append(r)
        closed = sum(1 for r in results if r.get("ok"))
        return {"ok": True, "closed": closed, "details": results}

    # ──────────────────────────────────────────────
    # Modify SL / TP
    # ──────────────────────────────────────────────
    def modify_position(self, ticket: int, sl: float = None, tp: float = None) -> dict:
        pos = mt5.positions_get(ticket=ticket)
        if not pos:
            return {"ok": False, "error": f"Position {ticket} not found"}
        p = pos[0]
        request = {
            "action":   mt5.TRADE_ACTION_SLTP,
            "symbol":   SYMBOL,
            "position": ticket,
            "sl":       round(sl, 2) if sl is not None else p.sl,
            "tp":       round(tp, 2) if tp is not None else p.tp,
        }
        result = mt5.order_send(request)
        if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
            err = mt5.last_error()
            return {"ok": False, "error": str(err)}
        return {"ok": True, "ticket": ticket, "sl": request["sl"], "tp": request["tp"]}
