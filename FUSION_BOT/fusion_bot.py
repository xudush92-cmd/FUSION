"""
FUSION Bot — Telegram orqali MT5 robotini boshqarish
Ko'p foydalanuvchili: admin hisob qo'shadi, foydalanuvchilar o'z robotini boshqaradi.
"""
import asyncio
import logging
from aiogram import Bot, Dispatcher, Router, F
from aiogram.types import Message, CallbackQuery
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup

from config import BOT_TOKEN, ADMIN_IDS
import database as db
import mt5_bridge
import ea_bridge
from keyboards import (
    admin_menu_kb, user_menu_kb, strategy_kb, settings_kb, timeframe_kb, symbol_kb
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("FUSION_BOT")

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher()
router = Router()


# === FSM HOLATLARI ===

class AddUserStates(StatesGroup):
    waiting_user_id = State()
    waiting_mt5_login = State()
    waiting_mt5_server = State()
    waiting_mt5_password = State()

class RemoveUserStates(StatesGroup):
    waiting_user_id = State()

class SettingsStates(StatesGroup):
    waiting_value = State()


# === YORDAMCHI ===

def is_admin(user_id: int) -> bool:
    return user_id in ADMIN_IDS


async def get_active_user(user_id: int) -> dict | None:
    """Foydalanuvchini olish — faqat faol (active) bo'lsa qaytaradi.
    Admin har doim ruxsatga ega."""
    user = await db.get_user(user_id)
    if not user:
        return None
    if is_admin(user_id):
        return user
    if user.get("status") != "active":
        return None
    return user


async def sync_user_to_ea(user: dict) -> None:
    """Foydalanuvchi sozlamalarini EA buyruq fayliga yozish (fayl bridge)."""
    if not user or not user.get("mt5_login"):
        return
    settings = await db.get_settings(user["user_id"])
    running = bool(user.get("robot_running"))
    ok, err = await asyncio.to_thread(
        ea_bridge.write_command,
        user["mt5_login"], running, user.get("strategy", "RSI_REVERSAL"), settings
    )
    if not ok:
        logger.warning(f"EA sinxronlash xatosi (user {user['user_id']}): {err}")


# noop — bo'sh callback (ajratuvchi chiziq uchun)
@router.callback_query(F.data == "noop")
async def noop_handler(callback: CallbackQuery):
    await callback.answer()


# === /start BUYRUQ ===

@router.message(Command("start"))
async def cmd_start(message: Message):
    user_id = message.from_user.id

    if is_admin(user_id):
        user = await db.get_user(user_id)
        robot_status = ""
        if user and user.get("mt5_login"):
            robot_status = (
                f"\nStrategiya: {user['strategy']}\n"
                f"Robot: {'Ishlayapti' if user['robot_running'] else 'Toxtatilgan'}\n"
            )
        await message.answer(
            "FUSION Boshqaruv Paneli\n\n"
            "Siz ADMIN sifatida kirdingiz.\n"
            f"{robot_status}\n"
            "Boshqarish:",
            reply_markup=admin_menu_kb()
        )
    else:
        user = await db.get_user(user_id)
        if user and user["status"] == "active":
            await message.answer(
                "🤖 FUSION Robot\n\n"
                f"Strategiya: {user['strategy']}\n"
                f"Robot: {'🟢 Ishlayapti' if user['robot_running'] else '🔴 Toxtatilgan'}\n\n"
                "Boshqarish:",
                reply_markup=user_menu_kb(),
    
            )
        else:
            await message.answer(
                "⛔ Sizga ruxsat berilmagan.\n"
                "Admin bilan bog'laning."
            )


# ============================================================
#                    ADMIN HANDLERLARI
# ============================================================

@router.callback_query(F.data == "admin:users")
async def admin_users_list(callback: CallbackQuery):
    if not is_admin(callback.from_user.id):
        return
    users = await db.get_all_users()
    if not users:
        await callback.message.edit_text("👥 Hozircha foydalanuvchi yo'q.",
                                         reply_markup=admin_menu_kb())
        return
    text = "👥 Foydalanuvchilar:\n\n"
    for u in users:
        status_icon = "🟢" if u["status"] == "active" else "🔴"
        robot_icon = "▶️" if u["robot_running"] else "⏹"
        text += (
            f"{status_icon} {u['user_id']} | "
            f"{u.get('username', '-')} | "
            f"MT5:{u['mt5_login'] or '-'} | "
            f"Robot:{robot_icon} | "
            f"{u['strategy']}\n"
        )
    await callback.message.edit_text(text, reply_markup=admin_menu_kb())
    await callback.answer()


@router.callback_query(F.data == "admin:add_user")
async def admin_add_user_start(callback: CallbackQuery, state: FSMContext):
    if not is_admin(callback.from_user.id):
        return
    await callback.message.edit_text("➕ Yangi foydalanuvchi Telegram ID sini kiriting:")
    await state.set_state(AddUserStates.waiting_user_id)
    await callback.answer()


@router.message(AddUserStates.waiting_user_id)
async def admin_add_user_id(message: Message, state: FSMContext):
    if not is_admin(message.from_user.id):
        return
    try:
        new_uid = int(message.text.strip())
    except ValueError:
        await message.answer("❌ Noto'g'ri ID. Raqam kiriting:")
        return
    await state.update_data(new_uid=new_uid)
    await message.answer(f"✅ ID: {new_uid}\n\nMT5 login raqamini kiriting:")
    await state.set_state(AddUserStates.waiting_mt5_login)


@router.message(AddUserStates.waiting_mt5_login)
async def admin_add_mt5_login(message: Message, state: FSMContext):
    if not is_admin(message.from_user.id):
        return
    try:
        login = int(message.text.strip())
    except ValueError:
        await message.answer("❌ Login raqam bo'lishi kerak:")
        return
    await state.update_data(mt5_login=login)
    await message.answer("MT5 server nomini kiriting (masalan: MetaQuotes-Demo):")
    await state.set_state(AddUserStates.waiting_mt5_server)


@router.message(AddUserStates.waiting_mt5_server)
async def admin_add_mt5_server(message: Message, state: FSMContext):
    if not is_admin(message.from_user.id):
        return
    server = message.text.strip()
    await state.update_data(mt5_server=server)
    await message.answer("MT5 parolni kiriting:")
    await state.set_state(AddUserStates.waiting_mt5_password)


@router.message(AddUserStates.waiting_mt5_password)
async def admin_add_mt5_password(message: Message, state: FSMContext):
    if not is_admin(message.from_user.id):
        return
    password = message.text.strip()
    data = await state.get_data()
    await state.clear()

    new_uid = data["new_uid"]
    mt5_login = data["mt5_login"]
    mt5_server = data["mt5_server"]

    # Foydalanuvchini qo'shish
    added = await db.add_user(new_uid, role="user")
    if not added:
        # allaqachon mavjud — faqat credentials yangilash
        pass

    await db.set_mt5_credentials(new_uid, mt5_login, mt5_server, password)

    # Ulanishni tekshirish
    connected, error_msg = await mt5_bridge.async_check_connection(mt5_login, mt5_server, password)

    if connected:
        await message.answer(
            f"✅ Foydalanuvchi qo'shildi!\n\n"
            f"Telegram ID: {new_uid}\n"
            f"MT5 Login: {mt5_login}\n"
            f"Server: {mt5_server}\n"
            f"Ulanish: ✅ Muvaffaqiyatli\n\n"
            f"Foydalanuvchi endi /start bilan kirishi mumkin.",
            reply_markup=admin_menu_kb(),

        )
    else:
        await message.answer(
            f"⚠️ Foydalanuvchi qo'shildi, LEKIN MT5 ulanish xatosi!\n\n"
            f"Telegram ID: {new_uid}\n"
            f"MT5 Login: {mt5_login}\n"
            f"Server: {mt5_server}\n"
            f"Ulanish: ❌ {error_msg}\n\n"
            f"💡 Yechim: login, server nomi va parolni tekshiring.\n"
            f"Ma'lumotlar saqlandi — keyinroq qayta ulanish mumkin.",
            reply_markup=admin_menu_kb(),

        )

    # Parolni o'chirish (xavfsizlik)
    try:
        await message.delete()
    except Exception:
        logger.debug("Parol xabarini o'chirib bo'lmadi")


@router.callback_query(F.data == "admin:remove_user")
async def admin_remove_user_start(callback: CallbackQuery, state: FSMContext):
    if not is_admin(callback.from_user.id):
        return
    await callback.message.edit_text("❌ O'chirmoqchi bo'lgan foydalanuvchi Telegram ID sini kiriting:")
    await state.set_state(RemoveUserStates.waiting_user_id)
    await callback.answer()


@router.message(RemoveUserStates.waiting_user_id)
async def admin_remove_user_confirm(message: Message, state: FSMContext):
    if not is_admin(message.from_user.id):
        return
    try:
        uid = int(message.text.strip())
    except ValueError:
        await message.answer("❌ Noto'g'ri ID:")
        return
    await state.clear()
    # O'chirishdan oldin MT5 login ni olamiz (bridge faylini tozalash uchun)
    target = await db.get_user(uid)
    target_login = target.get("mt5_login") if target else 0
    removed = await db.remove_user(uid)
    if removed:
        if target_login:
            await asyncio.to_thread(ea_bridge.clear_command, target_login)
        await message.answer(f"✅ Foydalanuvchi {uid} o'chirildi.", reply_markup=admin_menu_kb())
    else:
        await message.answer(f"⚠️ {uid} topilmadi.", reply_markup=admin_menu_kb())


@router.callback_query(F.data == "admin:status_all")
async def admin_status_all(callback: CallbackQuery):
    if not is_admin(callback.from_user.id):
        return
    users = await db.get_all_users()
    if not users:
        await callback.message.edit_text("Hisob yo'q.", reply_markup=admin_menu_kb())
        await callback.answer()
        return
    text = "📊 Umumiy holat:\n\n"
    for u in users:
        if u["mt5_login"]:
            info, error_msg = await mt5_bridge.async_get_account_info(u["mt5_login"], u["mt5_server"], u["mt5_password"])
            if info:
                text += (
                    f"👤 {u['user_id']} | {info['name']}\n"
                    f"   💰 Balans: ${info['balance']:.2f} | Foyda: ${info['profit']:.2f}\n\n"
                )
            else:
                text += f"👤 {u['user_id']} | ❌ {error_msg}\n\n"
        else:
            text += f"👤 {u['user_id']} | MT5 sozlanmagan\n\n"
    await callback.message.edit_text(text, reply_markup=admin_menu_kb())
    await callback.answer()


@router.callback_query(F.data == "admin:stop_all")
async def admin_stop_all(callback: CallbackQuery):
    if not is_admin(callback.from_user.id):
        return
    users = await db.get_all_users()
    count = 0
    errors = []
    for u in users:
        if u["mt5_login"] and u["robot_running"]:
            closed, error_msg = await mt5_bridge.async_close_all_positions(u["mt5_login"], u["mt5_server"], u["mt5_password"])
            await db.set_robot_state(u["user_id"], False)
            u["robot_running"] = 0
            await sync_user_to_ea(u)
            count += 1
            if error_msg:
                errors.append(f"{u['user_id']}: {error_msg}")

    text = f"🛑 Hammasi to'xtatildi. {count} ta hisob to'xtatildi."
    if errors:
        text += "\n\n⚠️ Muammolar:\n" + "\n".join(errors[:5])
    await callback.message.edit_text(text, reply_markup=admin_menu_kb())
    await callback.answer()


# ============================================================
#                 FOYDALANUVCHI HANDLERLARI
# ============================================================

@router.callback_query(F.data == "user:menu")
async def user_menu(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    await callback.message.edit_text(
        f"🤖 FUSION Robot\n\n"
        f"Strategiya: {user['strategy']}\n"
        f"Robot: {'🟢 Ishlayapti' if user['robot_running'] else '🔴 Toxtatilgan'}",
        reply_markup=user_menu_kb()
    )
    await callback.answer()


@router.callback_query(F.data == "user:start")
async def user_start_robot(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    if not user["mt5_login"]:
        await callback.answer("⚠️ MT5 hisob sozlanmagan. Admin bilan bog'laning.", show_alert=True)
        return

    # MT5 ulanishni tekshirish
    connected, error_msg = await mt5_bridge.async_check_connection(
        user["mt5_login"], user["mt5_server"], user["mt5_password"]
    )
    if not connected:
        await callback.message.edit_text(
            f"❌ MT5 ga ulanib bo'lmadi!\n\n"
            f"Sabab: {error_msg}\n\n"
            f"💡 Admin bilan bog'laning yoki keyinroq qayta urinib ko'ring.",
            reply_markup=user_menu_kb()
        )
        await callback.answer()
        return

    await db.set_robot_state(user["user_id"], True)
    user["robot_running"] = 1
    await sync_user_to_ea(user)
    await callback.message.edit_text(
        "▶️ Robot ishga tushirildi!\n\n"
        f"Strategiya: {user['strategy']}\n"
        "Robot bozorni kuzatyapti...",
        reply_markup=user_menu_kb()
    )
    await callback.answer()


@router.callback_query(F.data == "user:stop")
async def user_stop_robot(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    await db.set_robot_state(user["user_id"], False)
    user["robot_running"] = 0
    await sync_user_to_ea(user)
    # Ochiq pozitsiyalarni yopish
    if user["mt5_login"]:
        closed, error_msg = await mt5_bridge.async_close_all_positions(
            user["mt5_login"], user["mt5_server"], user["mt5_password"]
        )
        if error_msg:
            await callback.message.edit_text(
                f"⏹ Robot to'xtatildi.\n"
                f"{closed} ta pozitsiya yopildi.\n\n"
                f"⚠️ {error_msg}",
                reply_markup=user_menu_kb()
            )
        else:
            await callback.message.edit_text(
                f"⏹ Robot to'xtatildi.\n"
                f"{closed} ta pozitsiya yopildi.",
                reply_markup=user_menu_kb()
            )
    else:
        await callback.message.edit_text("⏹ Robot to'xtatildi.", reply_markup=user_menu_kb())
    await callback.answer()


@router.callback_query(F.data == "user:status")
async def user_status(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user or not user["mt5_login"]:
        await callback.answer("MT5 sozlanmagan", show_alert=True)
        return

    positions, error_msg = await mt5_bridge.async_get_positions(
        user["mt5_login"], user["mt5_server"], user["mt5_password"]
    )

    if error_msg:
        await callback.message.edit_text(
            f"❌ MT5 ulanish xatosi\n\n"
            f"Sabab: {error_msg}\n\n"
            f"💡 Internetni tekshiring yoki admin bilan bog'laning.",
            reply_markup=user_menu_kb()
        )
        await callback.answer()
        return

    if not positions:
        text = "📊 Holat: Ochiq savdo yo'q."
    else:
        text = f"📊 Ochiq savdolar ({len(positions)} ta):\n\n"
        total_profit = 0
        for p in positions:
            emoji = "🟢" if p["profit"] >= 0 else "🔴"
            text += f"{emoji} {p['type']} {p['symbol']} | {p['volume']} lot | ${p['profit']:.2f}\n"
            total_profit += p["profit"]
        text += f"\n💰 Jami foyda: ${total_profit:.2f}"
    await callback.message.edit_text(text, reply_markup=user_menu_kb())
    await callback.answer()


@router.callback_query(F.data == "user:balance")
async def user_balance(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user or not user["mt5_login"]:
        await callback.answer("MT5 sozlanmagan", show_alert=True)
        return

    info, error_msg = await mt5_bridge.async_get_account_info(
        user["mt5_login"], user["mt5_server"], user["mt5_password"]
    )

    if not info:
        await callback.message.edit_text(
            f"❌ MT5 ulanish xatosi\n\n"
            f"Sabab: {error_msg}\n\n"
            f"💡 Yechim: MT5 terminal ishlayotganini tekshiring.\n"
            f"Muammo davom etsa admin bilan bog'laning.",
            reply_markup=user_menu_kb()
        )
        await callback.answer()
        return

    text = (
        f"💰 Hisob ma'lumotlari:\n\n"
        f"👤 Ism: {info['name']}\n"
        f"💵 Balans: ${info['balance']:.2f}\n"
        f"📊 Equity: ${info['equity']:.2f}\n"
        f"📈 Foyda: ${info['profit']:.2f}\n"
        f"🔒 Margin: ${info['margin']:.2f}\n"
        f"💎 Erkin margin: ${info['free_margin']:.2f}\n"
        f"⚖️ Leverage: 1:{info['leverage']}\n"
        f"💱 Valyuta: {info['currency']}"
    )
    await callback.message.edit_text(text, reply_markup=user_menu_kb())
    await callback.answer()


# === STRATEGIYA TANLASH ===

@router.callback_query(F.data == "user:strategy")
async def user_strategy_menu(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    await callback.message.edit_text(
        f"🔄 Strategiya tanlang:\n\n"
        f"Hozirgi: {user['strategy']}",
        reply_markup=strategy_kb()
    )
    await callback.answer()


@router.callback_query(F.data.startswith("strat:"))
async def user_select_strategy(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    strategy = callback.data.split(":")[1]
    await db.set_strategy(user["user_id"], strategy)
    user["strategy"] = strategy
    await sync_user_to_ea(user)
    name = mt5_bridge.STRATEGIES.get(strategy, strategy)
    await callback.message.edit_text(
        f"✅ Strategiya o'zgartirildi!\n\n"
        f"Yangi: {name}",
        reply_markup=user_menu_kb()
    )
    await callback.answer()


# === SOZLAMALAR ===

@router.callback_query(F.data == "user:settings")
async def user_settings_menu(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    settings = await db.get_settings(user["user_id"])
    text = (
        "⚙️ Sozlamalar:\n\n"
        f"💱 Juftlik: {settings.get('symbol', 'grafikdagi')}\n"
        f"💎 Lot: {settings.get('lot', 0.10)}\n"
        f"🛑 Stop Loss: {settings.get('sl', 300)} punkt\n"
        f"🎯 Take Profit: {settings.get('tp', 600)} punkt\n"
        f"⚖️ Risk: {settings.get('risk', 1.0)}%\n"
        f"🕐 Timeframe: {settings.get('timeframe', 'M5')}"
    )
    await callback.message.edit_text(text, reply_markup=settings_kb())
    await callback.answer()


@router.callback_query(F.data == "user:symbol")
async def user_symbol_menu(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    settings = await db.get_settings(user["user_id"])
    current = settings.get("symbol", "grafikdagi")
    await callback.message.edit_text(
        f"💱 Savdo juftligini tanlang:\n\n"
        f"Hozirgi: {current}\n\n"
        f"⚠️ Eslatma: broker nomi farq qilishi mumkin "
        f"(masalan XAUUSDm, EURUSD.r). Agar savdo ochilmasa, "
        f"MT5 dagi aniq nomni admin bilan tekshiring.",
        reply_markup=symbol_kb()
    )
    await callback.answer()


@router.callback_query(F.data.startswith("sym:"))
async def user_select_symbol(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    symbol = callback.data.split(":")[1]
    settings = await db.get_settings(user["user_id"])
    settings["symbol"] = symbol
    await db.set_settings(user["user_id"], settings)
    await sync_user_to_ea(user)
    await callback.message.edit_text(
        f"✅ Juftlik o'zgartirildi: {symbol}",
        reply_markup=settings_kb()
    )
    await callback.answer()


@router.callback_query(F.data == "user:timeframe")
async def user_timeframe_menu(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    settings = await db.get_settings(user["user_id"])
    current_tf = settings.get("timeframe", "M5")
    await callback.message.edit_text(
        f"🕐 Timeframe tanlang:\n\nHozirgi: {current_tf}",
        reply_markup=timeframe_kb()
    )
    await callback.answer()


@router.callback_query(F.data.startswith("tf:"))
async def user_select_timeframe(callback: CallbackQuery):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    tf = callback.data.split(":")[1]
    settings = await db.get_settings(user["user_id"])
    settings["timeframe"] = tf
    await db.set_settings(user["user_id"], settings)
    await sync_user_to_ea(user)
    await callback.message.edit_text(
        f"✅ Timeframe o'zgartirildi: {tf}",
        reply_markup=settings_kb()
    )
    await callback.answer()


@router.callback_query(F.data.startswith("set:"))
async def user_change_setting(callback: CallbackQuery, state: FSMContext):
    user = await get_active_user(callback.from_user.id)
    if not user:
        await callback.answer("⛔ Ruxsat yo'q", show_alert=True)
        return
    param = callback.data.split(":")[1]
    labels = {
        "lot": "Yangi lot (masalan: 0.10)",
        "sl": "Yangi Stop Loss (punkt, masalan: 300)",
        "tp": "Yangi Take Profit (punkt, masalan: 600)",
        "risk": "Yangi Risk (%, masalan: 1.5)",
    }
    await state.update_data(setting_param=param)
    await callback.message.edit_text(f"✏️ {labels.get(param, param)} qiymatini kiriting:")
    await state.set_state(SettingsStates.waiting_value)
    await callback.answer()


@router.message(SettingsStates.waiting_value)
async def user_set_value(message: Message, state: FSMContext):
    user = await get_active_user(message.from_user.id)
    if not user:
        return
    try:
        value = float(message.text.strip())
    except ValueError:
        await message.answer("❌ Noto'g'ri format. Raqam kiriting (masalan: 0.10 yoki 300):")
        return

    data = await state.get_data()
    param = data.get("setting_param", "lot")

    # Qiymat chegaralarini tekshirish
    limits = {
        "lot": (0.01, 100.0, "Lot 0.01 dan 100 gacha bo'lishi kerak"),
        "sl": (10, 10000, "Stop Loss 10 dan 10000 punkt gacha"),
        "tp": (10, 50000, "Take Profit 10 dan 50000 punkt gacha"),
        "risk": (0.1, 50.0, "Risk 0.1% dan 50% gacha"),
    }

    if param in limits:
        min_val, max_val, hint = limits[param]
        if value < min_val or value > max_val:
            await message.answer(f"⚠️ {hint}. Qayta kiriting:")
            return

    await state.clear()

    settings = await db.get_settings(user["user_id"])
    settings[param] = value
    await db.set_settings(user["user_id"], settings)
    await sync_user_to_ea(user)

    labels = {"lot": "💎 Lot", "sl": "🛑 Stop Loss", "tp": "🎯 Take Profit", "risk": "⚖️ Risk"}
    await message.answer(
        f"✅ {labels.get(param, param)} = {value} ga o'zgartirildi.",
        reply_markup=user_menu_kb()
    )


# ============================================================
#                           MAIN
# ============================================================

async def main():
    await db.init_db()

    # Admin'ni DB ga qo'shish (agar yo'q bo'lsa)
    for admin_id in ADMIN_IDS:
        await db.add_user(admin_id, role="admin")

    dp.include_router(router)
    logger.info("FUSION Bot ishga tushdi...")
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
