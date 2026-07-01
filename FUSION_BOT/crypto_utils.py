"""
FUSION Bot — Shifrlash utilitalari (Fernet)
MT5 parollarini xavfsiz saqlash va o'qish uchun.
"""
from cryptography.fernet import Fernet
from config import ENCRYPTION_KEY


def get_fernet() -> Fernet:
    """Fernet obyektini olish"""
    return Fernet(ENCRYPTION_KEY.encode())


def encrypt_password(plain_password: str) -> str:
    """Parolni shifrlash (saqlash uchun)"""
    f = get_fernet()
    return f.encrypt(plain_password.encode()).decode()


def decrypt_password(encrypted_password: str) -> str:
    """Shifrlangan parolni ochish (ishlatish uchun)"""
    if not encrypted_password:
        return ""
    try:
        f = get_fernet()
        return f.decrypt(encrypted_password.encode()).decode()
    except Exception:
        # Agar deshifrlash xato bersa (eski ochiq parol bo'lishi mumkin)
        return encrypted_password


def generate_key() -> str:
    """Yangi shifrlash kalitini yaratish (birinchi marta o'rnatishda)"""
    return Fernet.generate_key().decode()
