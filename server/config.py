"""
config.py — Global configuration for XAUUSD Trading System
Broker: Exness | Symbol: XAUUSD | Fixed Lot: 0.05
"""

import os
from dotenv import load_dotenv

load_dotenv()

# ──────────────────────────────────────────────
# MT5 Connection
# ──────────────────────────────────────────────
MT5_LOGIN = int(os.getenv("MT5_LOGIN", "0"))
MT5_PASSWORD = os.getenv("MT5_PASSWORD", "")
MT5_SERVER = os.getenv("MT5_SERVER", "Exness-MT5Trial")   # Exness Demo server

# ──────────────────────────────────────────────
# Trading Settings
# ──────────────────────────────────────────────
SYMBOL = "XAUUSD"
FIXED_LOT = float(os.getenv("FIXED_LOT", "0.05"))        # Fixed lot size
MAGIC_NUMBER = 20240618                                     # Unique ID for bot orders
SLIPPAGE = 20                                               # Max slippage in points
MAX_POSITIONS = int(os.getenv("MAX_POSITIONS", "3"))       # Max concurrent positions
MAX_DAILY_LOSS_USD = float(os.getenv("MAX_DAILY_LOSS_USD", "100"))  # Daily loss guard ($)

# ──────────────────────────────────────────────
# Webhook Security
# ──────────────────────────────────────────────
WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET", "your_secret_token_here")

# ──────────────────────────────────────────────
# Server
# ──────────────────────────────────────────────
FLASK_HOST = "0.0.0.0"
FLASK_PORT = int(os.getenv("FLASK_PORT", "5000"))
FLASK_DEBUG = os.getenv("FLASK_DEBUG", "false").lower() == "true"

# ──────────────────────────────────────────────
# Signal Actions (expected in webhook JSON)
# ──────────────────────────────────────────────
ACTION_BUY        = "BUY"
ACTION_SELL       = "SELL"
ACTION_CLOSE      = "CLOSE"         # Close specific position by ticket or latest
ACTION_CLOSE_ALL  = "CLOSE_ALL"     # Close all open positions
ACTION_MODIFY     = "MODIFY"        # Modify SL/TP of open position
