"""
FUSION Bot — konfiguratsiya
"""
import os

# Telegram Bot
BOT_TOKEN = os.getenv("BOT_TOKEN", "")
ADMIN_IDS = [int(x) for x in os.getenv("ADMIN_IDS", "").split(",") if x.strip()]

# MT5 yo'li (VPS da)
MT5_PATH = os.getenv("MT5_PATH", r"C:\Program Files\MetaTrader 5\terminal64.exe")

# Database
DB_PATH = os.getenv("DB_PATH", "fusion_bot.db")
