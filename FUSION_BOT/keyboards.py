"""
FUSION Bot — Telegram tugmalar (InlineKeyboard)
"""
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton

# === ADMIN PANEL ===

def admin_menu_kb() -> InlineKeyboardMarkup:
    """Admin bosh menyu — admin + foydalanuvchi tugmalari"""
    return InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(text="▶️ START", callback_data="user:start"),
            InlineKeyboardButton(text="⏹ STOP", callback_data="user:stop"),
        ],
        [
            InlineKeyboardButton(text="📊 Holat", callback_data="user:status"),
            InlineKeyboardButton(text="💰 Balans", callback_data="user:balance"),
        ],
        [InlineKeyboardButton(text="🔄 Strategiya tanlash", callback_data="user:strategy")],
        [InlineKeyboardButton(text="⚙️ Sozlamalar", callback_data="user:settings")],
        [InlineKeyboardButton(text="━━━━ ADMIN ━━━━", callback_data="noop")],
        [InlineKeyboardButton(text="👥 Foydalanuvchilar", callback_data="admin:users")],
        [InlineKeyboardButton(text="➕ Yangi hisob qo'shish", callback_data="admin:add_user")],
        [InlineKeyboardButton(text="❌ Hisob olib tashlash", callback_data="admin:remove_user")],
        [InlineKeyboardButton(text="📊 Umumiy holat", callback_data="admin:status_all")],
        [InlineKeyboardButton(text="🛑 Hammani to'xtatish", callback_data="admin:stop_all")],
    ])


# === FOYDALANUVCHI PANEL ===

def user_menu_kb() -> InlineKeyboardMarkup:
    """Foydalanuvchi bosh menyu"""
    return InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(text="▶️ START", callback_data="user:start"),
            InlineKeyboardButton(text="⏹ STOP", callback_data="user:stop"),
        ],
        [
            InlineKeyboardButton(text="📊 Holat", callback_data="user:status"),
            InlineKeyboardButton(text="💰 Balans", callback_data="user:balance"),
        ],
        [InlineKeyboardButton(text="🔄 Strategiya tanlash", callback_data="user:strategy")],
        [InlineKeyboardButton(text="⚙️ Sozlamalar", callback_data="user:settings")],
    ])


# === STRATEGIYA TANLASH ===

def strategy_kb() -> InlineKeyboardMarkup:
    """Strategiya tanlash tugmalari"""
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📈 RSI Reversal", callback_data="strat:RSI_REVERSAL")],
        [InlineKeyboardButton(text="📊 MA Crossover", callback_data="strat:MA_CROSSOVER")],
        [InlineKeyboardButton(text="📉 MACD Crossover", callback_data="strat:MACD_CROSS")],
        [InlineKeyboardButton(text="🎯 Bollinger Bounce", callback_data="strat:BOLLINGER_BOUNCE")],
        [InlineKeyboardButton(text="🔀 Stochastic", callback_data="strat:STOCHASTIC")],
        [InlineKeyboardButton(text="📐 CCI", callback_data="strat:CCI")],
        [InlineKeyboardButton(text="🚀 Trend Following", callback_data="strat:TREND_FOLLOWING")],
        [InlineKeyboardButton(text="━━━ SKALPING ━━━", callback_data="noop")],
        [InlineKeyboardButton(text="⚡ Skalp RSI (M1/M5)", callback_data="strat:SCALP_RSI")],
        [InlineKeyboardButton(text="⚡ Skalp MA (M1/M5)", callback_data="strat:SCALP_MA")],
        [InlineKeyboardButton(text="⚡ Skalp Stochastic (M1/M5)", callback_data="strat:SCALP_STOCH")],
        [InlineKeyboardButton(text="🔙 Ortga", callback_data="user:menu")],
    ])


# === SOZLAMALAR ===

def settings_kb() -> InlineKeyboardMarkup:
    """Sozlamalar tugmalari"""
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="💎 Lot o'zgartirish", callback_data="set:lot")],
        [InlineKeyboardButton(text="🛑 Stop Loss", callback_data="set:sl")],
        [InlineKeyboardButton(text="🎯 Take Profit", callback_data="set:tp")],
        [InlineKeyboardButton(text="⚖️ Risk %", callback_data="set:risk")],
        [InlineKeyboardButton(text="🔙 Ortga", callback_data="user:menu")],
    ])


# === TASDIQLASH ===

def confirm_kb(action: str) -> InlineKeyboardMarkup:
    """Tasdiqlash (Ha/Yo'q)"""
    return InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(text="✅ Ha", callback_data=f"confirm:yes:{action}"),
            InlineKeyboardButton(text="❌ Yo'q", callback_data=f"confirm:no:{action}"),
        ]
    ])
