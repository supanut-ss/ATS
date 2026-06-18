"""
signal_handler.py — Parse and validate TradingView webhook payloads
Expected JSON format from TradingView Pine Script alert:
{
    "token":   "your_secret_token",
    "action":  "BUY" | "SELL" | "CLOSE" | "CLOSE_ALL" | "MODIFY",
    "symbol":  "XAUUSD",
    "sl":      2310.00,     // optional: Stop Loss price
    "tp":      2340.00,     // optional: Take Profit price
    "ticket":  12345678,    // required for CLOSE/MODIFY
    "comment": "Sweep+MSS+Vol"
}
"""

import logging
from config import WEBHOOK_SECRET, SYMBOL, ACTION_BUY, ACTION_SELL, ACTION_CLOSE, ACTION_CLOSE_ALL, ACTION_MODIFY

logger = logging.getLogger(__name__)


class SignalHandler:
    VALID_ACTIONS = {ACTION_BUY, ACTION_SELL, ACTION_CLOSE, ACTION_CLOSE_ALL, ACTION_MODIFY}

    def parse(self, data: dict) -> dict:
        """
        Validate and parse incoming webhook JSON.
        Returns parsed signal dict or raises ValueError.
        """
        if not isinstance(data, dict):
            raise ValueError("Payload must be a JSON object")

        # Auth check
        token = data.get("token", "")
        if WEBHOOK_SECRET and token != WEBHOOK_SECRET:
            raise PermissionError("Invalid token")

        action = str(data.get("action", "")).upper()
        if action not in self.VALID_ACTIONS:
            raise ValueError(f"Invalid action '{action}'. Valid: {self.VALID_ACTIONS}")

        symbol = str(data.get("symbol", SYMBOL)).upper()
        if symbol != SYMBOL:
            raise ValueError(f"Symbol mismatch: expected {SYMBOL}, got {symbol}")

        signal = {
            "action":  action,
            "symbol":  symbol,
            "sl":      float(data["sl"]) if data.get("sl") else 0.0,
            "tp":      float(data["tp"]) if data.get("tp") else 0.0,
            "ticket":  int(data["ticket"]) if data.get("ticket") else None,
            "comment": str(data.get("comment", "TradingView"))[:31],
        }

        logger.info(f"Signal parsed: {signal}")
        return signal
