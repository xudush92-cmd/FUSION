"""
FUSION Bot — foydalanuvchilar va hisoblar ma'lumotlar bazasi (SQLite)
"""
import aiosqlite
import json
from config import DB_PATH
from crypto_utils import encrypt_password, decrypt_password

async def init_db():
    """Jadvalni yaratish (mavjud bo'lsa tegmaydi)"""
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS users (
                user_id INTEGER PRIMARY KEY,
                username TEXT DEFAULT '',
                role TEXT DEFAULT 'user',
                mt5_login INTEGER DEFAULT 0,
                mt5_server TEXT DEFAULT '',
                mt5_password TEXT DEFAULT '',
                status TEXT DEFAULT 'active',
                strategy TEXT DEFAULT 'RSI_REVERSAL',
                settings TEXT DEFAULT '{}',
                robot_running INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        await db.commit()


# === FOYDALANUVCHI CRUD ===

async def add_user(user_id: int, username: str = "", role: str = "user") -> bool:
    """Yangi foydalanuvchi qo'shish"""
    async with aiosqlite.connect(DB_PATH) as db:
        try:
            await db.execute(
                "INSERT INTO users (user_id, username, role) VALUES (?, ?, ?)",
                (user_id, username, role)
            )
            await db.commit()
            return True
        except aiosqlite.IntegrityError:
            return False  # allaqachon mavjud


async def remove_user(user_id: int) -> bool:
    """Foydalanuvchini o'chirish"""
    async with aiosqlite.connect(DB_PATH) as db:
        cur = await db.execute("DELETE FROM users WHERE user_id = ?", (user_id,))
        await db.commit()
        return cur.rowcount > 0


async def get_user(user_id: int) -> dict | None:
    """Foydalanuvchi ma'lumotlarini olish (parol deshifrlanadi)"""
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        cur = await db.execute("SELECT * FROM users WHERE user_id = ?", (user_id,))
        row = await cur.fetchone()
        if not row:
            return None
        user = dict(row)
        # Parolni deshifrlash
        if user.get("mt5_password"):
            user["mt5_password"] = decrypt_password(user["mt5_password"])
        return user


async def get_all_users() -> list:
    """Barcha foydalanuvchilar ro'yxati (parollar deshifrlanadi)"""
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        cur = await db.execute("SELECT * FROM users ORDER BY created_at")
        rows = await cur.fetchall()
        users = []
        for r in rows:
            user = dict(r)
            if user.get("mt5_password"):
                user["mt5_password"] = decrypt_password(user["mt5_password"])
            users.append(user)
        return users


async def update_user(user_id: int, **kwargs) -> bool:
    """Foydalanuvchi ma'lumotlarini yangilash"""
    if not kwargs:
        return False
    fields = ", ".join(f"{k} = ?" for k in kwargs.keys())
    values = list(kwargs.values()) + [user_id]
    async with aiosqlite.connect(DB_PATH) as db:
        cur = await db.execute(
            f"UPDATE users SET {fields} WHERE user_id = ?", values
        )
        await db.commit()
        return cur.rowcount > 0


# === MT5 HISOB RAQAMLARI ===

async def set_mt5_credentials(user_id: int, login: int, server: str, password: str) -> bool:
    """MT5 hisob ma'lumotlarini saqlash (parol shifrlangan holda)"""
    encrypted_pw = encrypt_password(password)
    return await update_user(user_id, mt5_login=login, mt5_server=server, mt5_password=encrypted_pw)


# === STRATEGIYA VA SOZLAMALAR ===

async def set_strategy(user_id: int, strategy: str) -> bool:
    """Strategiyani o'zgartirish"""
    return await update_user(user_id, strategy=strategy)


async def set_settings(user_id: int, settings: dict) -> bool:
    """Sozlamalarni saqlash (JSON)"""
    return await update_user(user_id, settings=json.dumps(settings))


async def get_settings(user_id: int) -> dict:
    """Sozlamalarni olish"""
    user = await get_user(user_id)
    if user and user.get("settings"):
        try:
            return json.loads(user["settings"])
        except json.JSONDecodeError:
            pass
    return {}


async def set_robot_state(user_id: int, running: bool) -> bool:
    """Robot holatini saqlash (ishga tushganmi)"""
    return await update_user(user_id, robot_running=1 if running else 0)
