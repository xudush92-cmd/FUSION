"""
FUSION Bot — Shifrlash utilitalari (Fernet)
MT5 parollarini xavfsiz saqlash va o'qish uchun.

Agar ENCRYPTION_KEY .env da yo'q yoki noto'g'ri bo'lsa, parollar
shifrlanmasdan (ochiq) saqlanadi va ogohlantirish log qilinadi.
Bu bot ishdan chiqishining oldini oladi.
"""
import logging
from cryptography.fernet import Fernet
from config import ENCRYPTION_KEY

logger = logging.getLogger("CRYPTO")

# Prefiks — shifrlangan parolni ochiq parondan farqlash uchun
_ENC_PREFIX = "enc::"

# Fernet obyektini bir marta yaratib qo'yamiz (kalit to'g'ri bo'lsa)
_fernet: Fernet | None = None
try:
    if ENCRYPTION_KEY:
        _fernet = Fernet(ENCRYPTION_KEY.encode())
    else:
        logger.warning(
            "ENCRYPTION_KEY o'rnatilmagan! Parollar OCHIQ saqlanadi. "
            "Xavfsizlik uchun .env ga ENCRYPTION_KEY qo'shing."
        )
except Exception as e:
    logger.error(f"ENCRYPTION_KEY noto'g'ri: {e}. Parollar OCHIQ saqlanadi.")
    _fernet = None


def encryption_enabled() -> bool:
    """Shifrlash faolmi (kalit to'g'ri o'rnatilganmi)"""
    return _fernet is not None


def encrypt_password(plain_password: str) -> str:
    """Parolni shifrlash (saqlash uchun). Kalit yo'q bo'lsa ochiq qaytaradi."""
    if not plain_password:
        return ""
    if _fernet is None:
        return plain_password  # shifrlashsiz saqlanadi
    try:
        token = _fernet.encrypt(plain_password.encode()).decode()
        return _ENC_PREFIX + token
    except Exception as e:
        logger.error(f"Shifrlash xatosi: {e}")
        return plain_password


def decrypt_password(stored_password: str) -> str:
    """Saqlangan parolni ochish. Shifrlanmagan (eski) parollarni ham qo'llab-quvvatlaydi."""
    if not stored_password:
        return ""
    # Shifrlanmagan (prefikssiz) — eski yoki ochiq parol
    if not stored_password.startswith(_ENC_PREFIX):
        return stored_password
    # Prefiksni olib tashlab deshifrlash
    token = stored_password[len(_ENC_PREFIX):]
    if _fernet is None:
        logger.error("Shifrlangan parol bor, lekin ENCRYPTION_KEY yo'q — deshifrlab bo'lmaydi.")
        return ""
    try:
        return _fernet.decrypt(token.encode()).decode()
    except Exception as e:
        logger.error(f"Deshifrlash xatosi: {e}")
        return ""


def generate_key() -> str:
    """Yangi shifrlash kalitini yaratish (birinchi marta o'rnatishda)"""
    return Fernet.generate_key().decode()
