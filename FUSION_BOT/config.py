"""
FUSION Bot — konfiguratsiya
"""
import os
from dotenv import load_dotenv

load_dotenv()

# Telegram Bot
BOT_TOKEN = os.getenv("BOT_TOKEN", "")
ADMIN_IDS = [int(x) for x in os.getenv("ADMIN_IDS", "").split(",") if x.strip()]

# MT5 yo'li (VPS da)
MT5_PATH = os.getenv("MT5_PATH", r"C:\Program Files\MetaTrader 5\terminal64.exe")

# Savdo dvigateli: PYTHON (standart) yoki EA.
# Faqat bittasi ishlaydi — bu bir signal uchun ikki marta savdo ochilishini oldini oladi.
TRADING_ENGINE = os.getenv("TRADING_ENGINE", "PYTHON").strip().upper()
if TRADING_ENGINE not in {"PYTHON", "EA"}:
    raise ValueError("TRADING_ENGINE faqat PYTHON yoki EA bo'lishi mumkin")

# Database
DB_PATH = os.getenv("DB_PATH", "fusion_bot.db")

# Shifrlash kaliti (Fernet) — birinchi marta:
# python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# natijani .env ga qo'ying
ENCRYPTION_KEY = os.getenv("ENCRYPTION_KEY", "")
