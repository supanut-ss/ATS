"""
risk_manager.py — Risk management guard before executing orders
Exness XAUUSD | Fixed Lot 0.05
"""

import MetaTrader5 as mt5
import logging
from datetime import datetime, timezone
from config import (
    FIXED_LOT, MAX_POSITIONS, MAX_DAILY_LOSS_USD,
    MAGIC_NUMBER, SYMBOL
)

logger = logging.getLogger(__name__)


class RiskManager:
    def validate_open(self, action: str) -> dict:
        """
        Run all pre-trade checks before placing a new order.
        Returns {"ok": True} if safe to trade, or {"ok": False, "reason": "..."}
        """
        # 1. Check max concurrent positions
        positions = mt5.positions_get(symbol=SYMBOL) or []
        bot_positions = [p for p in positions if p.magic == MAGIC_NUMBER]
        if len(bot_positions) >= MAX_POSITIONS:
            return {"ok": False, "reason": f"Max positions reached ({MAX_POSITIONS})"}

        # 2. Check daily loss limit
        daily_pnl = self._get_daily_pnl()
        if daily_pnl <= -MAX_DAILY_LOSS_USD:
            return {
                "ok": False,
                "reason": f"Daily loss limit hit (${daily_pnl:.2f} / -${MAX_DAILY_LOSS_USD})",
            }

        # 3. Check account equity > 0
        acc = mt5.account_info()
        if acc is None or acc.equity <= 0:
            return {"ok": False, "reason": "Cannot read account info or equity is zero"}

        # 4. Lot size sanity
        sym = mt5.symbol_info(SYMBOL)
        if sym:
            if FIXED_LOT < sym.volume_min:
                return {"ok": False, "reason": f"Lot {FIXED_LOT} < min {sym.volume_min}"}
            if FIXED_LOT > sym.volume_max:
                return {"ok": False, "reason": f"Lot {FIXED_LOT} > max {sym.volume_max}"}

        logger.info(f"Risk check passed | positions={len(bot_positions)} daily_pnl=${daily_pnl:.2f}")
        return {"ok": True}

    def _get_daily_pnl(self) -> float:
        """Get sum of today's closed deal profits + current open position profits."""
        # Open positions PnL
        positions = mt5.positions_get(symbol=SYMBOL) or []
        open_pnl = sum(p.profit + p.swap for p in positions if p.magic == MAGIC_NUMBER)

        # Closed deals today
        today = datetime.now(tz=timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        deals = mt5.history_deals_get(today, datetime.now(tz=timezone.utc)) or []
        closed_pnl = sum(
            d.profit + d.swap + d.fee
            for d in deals
            if d.symbol == SYMBOL and d.magic == MAGIC_NUMBER
        )
        return round(open_pnl + closed_pnl, 2)

    def get_risk_status(self) -> dict:
        return {
            "fixed_lot":         FIXED_LOT,
            "max_positions":     MAX_POSITIONS,
            "max_daily_loss":    MAX_DAILY_LOSS_USD,
            "daily_pnl":         self._get_daily_pnl(),
            "open_positions":    len([p for p in (mt5.positions_get(symbol=SYMBOL) or []) if p.magic == MAGIC_NUMBER]),
        }
