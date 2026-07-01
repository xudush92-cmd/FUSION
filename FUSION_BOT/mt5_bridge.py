"""
FUSION Bot — MetaTrader 5 bilan bog'lanish (Python API)
Bu modul MT5 ga ulanadi, savdo ochadi/yopadi, holat ko'rsatadi.
Ulanish cache qilinadi — har safar qayta login qilinmaydi.
"""
import logging
import time
import MetaTrader5 as mt5
from config import MT5_PATH

logger = logging.getLogger("MT5_BRIDGE")

# Tayyor strategiyalar nomi va tavsifi
STRATEGIES = {
    "RSI_REVERSAL":      "RSI Reversal (RSI<30 BUY, >70 SELL)",
    "MA_CROSSOVER":      "MA Crossover (tez/sekin MA kesishuvi)",
    "MACD_CROSS":        "MACD Crossover (main/signal kesishuvi)",
    "BOLLINGER_BOUNCE":  "Bollinger Bounce (chiziqqa tegish)",
    "STOCHASTIC":        "Stochastic (<20 BUY, >80 SELL)",
    "CCI":               "CCI (<-100 BUY, >100 SELL)",
    "TREND_FOLLOWING":   "Trend Following (MA + ADX filtri)",
    "SCALP_RSI":         "Skalping RSI (M1/M5, RSI<25 BUY, >75 SELL)",
    "SCALP_MA":          "Skalping MA (M1/M5, tez MA kesishuvi)",
    "SCALP_STOCH":       "Skalping Stochastic (M1/M5, <15 BUY, >85 SELL)",
}


# === ULANISH CACHE ===

class MT5Connection:
    """MT5 ulanishni cache qilish — qayta-qayta login qilmaslik uchun"""

    def __init__(self):
        self._current_login: int = 0
        self._current_server: str = ""
        self._last_connect_time: float = 0
        self._initialized: bool = False
        # 5 daqiqa ichida qayta ulanish kerak emas
        self.CACHE_TTL: int = 300

    @property
    def is_valid(self) -> bool:
        """Cache hali amal qiladimi"""
        if not self._initialized or not self._current_login:
            return False
        elapsed = time.time() - self._last_connect_time
        return elapsed < self.CACHE_TTL

    def _needs_reconnect(self, login: int, server: str) -> bool:
        """Qayta ulanish kerakmi tekshirish"""
        if not self.is_valid:
            return True
        if login != self._current_login or server != self._current_server:
            return True
        # MT5 terminal hali ishlayaptimi tekshirish
        info = mt5.account_info()
        if info is None:
            return True
        return False

    def connect(self, login: int, server: str, password: str) -> tuple[bool, str]:
        """
        MT5 ga ulanish (cache bilan).
        Qaytaradi: (muvaffaqiyat, xato_xabari)
        """
        # Agar cache amal qilsa va bir xil hisob — qayta ulanmaymiz
        if not self._needs_reconnect(login, server):
            return True, ""

        # Yangi ulanish
        if not self._initialized:
            if not mt5.initialize(MT5_PATH):
                error = mt5.last_error()
                error_msg = f"MT5 terminalni ishga tushirib bo'lmadi (kod: {error})"
                logger.error(error_msg)
                return False, error_msg
            self._initialized = True

        # Login
        authorized = mt5.login(login, password=password, server=server)
        if not authorized:
            error = mt5.last_error()
            error_code = error[0] if error else 0

            # Xato turlarini aniqlash
            if error_code == -2:
                error_msg = "MT5 terminal topilmadi yoki ishlamayapti"
            elif error_code == -10004:
                error_msg = "Login yoki parol noto'g'ri"
            elif error_code == -10003:
                error_msg = "Server nomi noto'g'ri yoki ulanib bo'lmadi"
            else:
                error_msg = f"MT5 login xatosi (kod: {error_code})"

            logger.error(f"MT5 login xato: login={login}, server={server}, error={error}")
            return False, error_msg

        # Cache yangilash
        self._current_login = login
        self._current_server = server
        self._last_connect_time = time.time()
        logger.info(f"MT5 ulanish muvaffaqiyatli: login={login}, server={server}")
        return True, ""

    def disconnect(self):
        """Ulanishni yopish"""
        if self._initialized:
            mt5.shutdown()
            self._initialized = False
            self._current_login = 0
            self._current_server = ""
            logger.info("MT5 ulanish yopildi")


# Global ulanish obyekti
_connection = MT5Connection()


# === UMUMIY FUNKSIYALAR ===

def login_account(login: int, server: str, password: str) -> tuple[bool, str]:
    """
    MT5 hisobga kirish (cache bilan).
    Qaytaradi: (muvaffaqiyat, xato_xabari)
    """
    return _connection.connect(login, server, password)


def shutdown_mt5():
    """MT5 ulanishni yopish"""
    _connection.disconnect()


def get_account_info(login: int, server: str, password: str) -> tuple[dict | None, str]:
    """
    Hisob ma'lumotlarini olish.
    Qaytaradi: (ma'lumotlar_dict yoki None, xato_xabari)
    """
    ok, error = login_account(login, server, password)
    if not ok:
        return None, error

    info = mt5.account_info()
    if info is None:
        return None, "Hisob ma'lumotlarini olishda xato yuz berdi"

    return {
        "balance": info.balance,
        "equity": info.equity,
        "profit": info.profit,
        "margin": info.margin,
        "free_margin": info.margin_free,
        "leverage": info.leverage,
        "name": info.name,
        "server": info.server,
        "currency": info.currency,
    }, ""


def get_positions(login: int, server: str, password: str) -> tuple[list, str]:
    """
    Ochiq pozitsiyalarni olish.
    Qaytaradi: (pozitsiyalar_list, xato_xabari)
    """
    ok, error = login_account(login, server, password)
    if not ok:
        return [], error

    positions = mt5.positions_get()
    if positions is None:
        return [], ""

    result = []
    for p in positions:
        result.append({
            "ticket": p.ticket,
            "symbol": p.symbol,
            "type": "BUY" if p.type == 0 else "SELL",
            "volume": p.volume,
            "open_price": p.price_open,
            "current_price": p.price_current,
            "profit": p.profit,
            "sl": p.sl,
            "tp": p.tp,
        })
    return result, ""


def close_all_positions(login: int, server: str, password: str) -> tuple[int, str]:
    """
    Barcha ochiq pozitsiyalarni yopish.
    Qaytaradi: (yopilganlar_soni, xato_xabari)
    """
    ok, error = login_account(login, server, password)
    if not ok:
        return 0, error

    positions = mt5.positions_get()
    if not positions:
        return 0, ""

    closed = 0
    errors = []
    for p in positions:
        tick = mt5.symbol_info_tick(p.symbol)
        if tick is None:
            errors.append(f"{p.symbol}: narx olinmadi")
            continue
        price = tick.bid if p.type == 0 else tick.ask
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": p.symbol,
            "volume": p.volume,
            "type": mt5.ORDER_TYPE_SELL if p.type == 0 else mt5.ORDER_TYPE_BUY,
            "position": p.ticket,
            "price": price,
            "deviation": 30,
            "magic": 777001,
            "comment": "FUSION_BOT close",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        result = mt5.order_send(request)
        if result and result.retcode == mt5.TRADE_RETCODE_DONE:
            closed += 1
        else:
            retcode = result.retcode if result else "noma'lum"
            errors.append(f"{p.symbol} #{p.ticket}: yopilmadi (kod: {retcode})")
            logger.warning(f"Pozitsiya yopish xatosi: {p.symbol} #{p.ticket}, retcode={retcode}")

    if errors:
        error_msg = f"{closed} yopildi, {len(errors)} xato: {'; '.join(errors[:3])}"
        return closed, error_msg

    return closed, ""


def check_connection(login: int, server: str, password: str) -> tuple[bool, str]:
    """
    MT5 ga ulanishni tekshirish.
    Qaytaradi: (muvaffaqiyat, xato_xabari)
    """
    return login_account(login, server, password)
