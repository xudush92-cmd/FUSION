"""
FUSION Bot — MetaTrader 5 bilan bog'lanish (Python API)
Bu modul MT5 ga ulanadi, savdo ochadi/yopadi, holat ko'rsatadi.
"""
import MetaTrader5 as mt5
from config import MT5_PATH

# Tayyor strategiyalar nomi va tavsifi
STRATEGIES = {
    "RSI_REVERSAL":      "RSI Reversal (RSI<30 BUY, >70 SELL)",
    "MA_CROSSOVER":      "MA Crossover (tez/sekin MA kesishuvi)",
    "MACD_CROSS":        "MACD Crossover (main/signal kesishuvi)",
    "BOLLINGER_BOUNCE":  "Bollinger Bounce (chiziqqa tegish)",
    "STOCHASTIC":        "Stochastic (<20 BUY, >80 SELL)",
    "CCI":               "CCI (<-100 BUY, >100 SELL)",
    "TREND_FOLLOWING":   "Trend Following (MA + ADX filtri)",
}


def init_mt5() -> bool:
    """MT5 terminalni ishga tushirish"""
    if not mt5.initialize(MT5_PATH):
        print(f"MT5 init xatosi: {mt5.last_error()}")
        return False
    return True


def shutdown_mt5():
    """MT5 ulanishni yopish"""
    mt5.shutdown()


def login_account(login: int, server: str, password: str) -> bool:
    """MT5 hisobga kirish"""
    if not init_mt5():
        return False
    authorized = mt5.login(login, password=password, server=server)
    if not authorized:
        print(f"MT5 login xatosi: {mt5.last_error()}")
        return False
    return True


def get_account_info(login: int, server: str, password: str) -> dict | None:
    """Hisob ma'lumotlarini olish"""
    if not login_account(login, server, password):
        return None
    info = mt5.account_info()
    if info is None:
        return None
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
    }


def get_positions(login: int, server: str, password: str) -> list:
    """Ochiq pozitsiyalarni olish"""
    if not login_account(login, server, password):
        return []
    positions = mt5.positions_get()
    if positions is None:
        return []
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
    return result


def close_all_positions(login: int, server: str, password: str) -> int:
    """Barcha ochiq pozitsiyalarni yopish"""
    if not login_account(login, server, password):
        return 0
    positions = mt5.positions_get()
    if not positions:
        return 0
    closed = 0
    for p in positions:
        tick = mt5.symbol_info_tick(p.symbol)
        if tick is None:
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
    return closed


def check_connection(login: int, server: str, password: str) -> bool:
    """MT5 ga ulanishni tekshirish"""
    return login_account(login, server, password)
