"""
FUSION Bot — mustaqil savdo dvigateli (Python)

Bu modul MT5 dan narx ma'lumotlarini oladi, indikatorlarni hisoblaydi,
strategiya signalini aniqlaydi va savdo ochadi/yopadi.
EA (MQL5 robot) kerak emas — hammasi shu yerda bajariladi.

MUHIM: MT5 Python API bir vaqtda bitta hisobga ulanadi, shuning uchun
savdo tsikli har bir foydalanuvchi uchun navbat bilan ishlaydi
(mt5_bridge._mt5_lock orqali).
"""
import logging
import numpy as np
import MetaTrader5 as mt5

import mt5_bridge

logger = logging.getLogger("TRADER")

MAGIC = 777001  # FUSION robot ID (EA bilan bir xil)

# Timeframe nomlarini MT5 konstantalariga bog'lash
TF_MAP = {
    "M1":  mt5.TIMEFRAME_M1,
    "M5":  mt5.TIMEFRAME_M5,
    "M15": mt5.TIMEFRAME_M15,
    "M30": mt5.TIMEFRAME_M30,
    "H1":  mt5.TIMEFRAME_H1,
    "H4":  mt5.TIMEFRAME_H4,
    "D1":  mt5.TIMEFRAME_D1,
    "W1":  mt5.TIMEFRAME_W1,
}

# Har bir foydalanuvchi uchun oxirgi qayta ishlangan bar (takroriy savdoning oldini olish)
_last_bar: dict = {}


# ==================================================================
#                       INDIKATORLAR
# ==================================================================

def ema(values: np.ndarray, period: int) -> np.ndarray:
    k = 2.0 / (period + 1)
    out = np.zeros_like(values, dtype=float)
    out[0] = values[0]
    for i in range(1, len(values)):
        out[i] = values[i] * k + out[i - 1] * (1 - k)
    return out


def sma(values: np.ndarray, period: int) -> np.ndarray:
    out = np.full(len(values), np.nan, dtype=float)
    for i in range(period - 1, len(values)):
        out[i] = values[i - period + 1:i + 1].mean()
    return out


def rsi(close: np.ndarray, period: int = 14) -> np.ndarray:
    n = len(close)
    out = np.full(n, 50.0, dtype=float)
    if n <= period:
        return out
    deltas = np.diff(close)
    seed = deltas[:period]
    up = seed[seed > 0].sum() / period
    down = -seed[seed < 0].sum() / period

    def _rsi_val(u, d):
        # Harakat yo'q (tekis bozor) — neytral 50, noto'g'ri signal bermaydi
        if u == 0 and d == 0:
            return 50.0
        if d == 0:
            return 100.0
        rs = u / d
        return 100 - 100 / (1 + rs)

    out[period] = _rsi_val(up, down)
    for i in range(period + 1, n):
        delta = deltas[i - 1]
        upval = max(delta, 0.0)
        downval = -min(delta, 0.0)
        up = (up * (period - 1) + upval) / period
        down = (down * (period - 1) + downval) / period
        out[i] = _rsi_val(up, down)
    return out


def macd(close: np.ndarray, fast: int = 12, slow: int = 26, signal: int = 9):
    macd_line = ema(close, fast) - ema(close, slow)
    signal_line = ema(macd_line, signal)
    return macd_line, signal_line


def stochastic_k(high, low, close, period: int = 5, slowing: int = 3) -> np.ndarray:
    n = len(close)
    raw = np.full(n, 50.0, dtype=float)
    for i in range(period - 1, n):
        hh = high[i - period + 1:i + 1].max()
        ll = low[i - period + 1:i + 1].min()
        raw[i] = 100 * (close[i] - ll) / (hh - ll) if hh != ll else 50.0
    # slowing (SMA)
    return sma(raw, slowing)


def cci(high, low, close, period: int = 14) -> np.ndarray:
    n = len(close)
    out = np.zeros(n, dtype=float)
    tp = (high + low + close) / 3.0
    for i in range(period - 1, n):
        window = tp[i - period + 1:i + 1]
        m = window.mean()
        md = np.abs(window - m).mean()
        out[i] = (tp[i] - m) / (0.015 * md) if md != 0 else 0.0
    return out


def adx(high, low, close, period: int = 14) -> np.ndarray:
    n = len(close)
    out = np.zeros(n, dtype=float)
    if n <= period * 2:
        return out
    tr = np.zeros(n)
    plus_dm = np.zeros(n)
    minus_dm = np.zeros(n)
    for i in range(1, n):
        up = high[i] - high[i - 1]
        down = low[i - 1] - low[i]
        plus_dm[i] = up if (up > down and up > 0) else 0.0
        minus_dm[i] = down if (down > up and down > 0) else 0.0
        tr[i] = max(high[i] - low[i], abs(high[i] - close[i - 1]), abs(low[i] - close[i - 1]))

    atr = tr[1:period + 1].sum()
    s_plus = plus_dm[1:period + 1].sum()
    s_minus = minus_dm[1:period + 1].sum()
    dx = np.zeros(n)
    for i in range(period + 1, n):
        atr = atr - atr / period + tr[i]
        s_plus = s_plus - s_plus / period + plus_dm[i]
        s_minus = s_minus - s_minus / period + minus_dm[i]
        pdi = 100 * s_plus / atr if atr != 0 else 0.0
        mdi = 100 * s_minus / atr if atr != 0 else 0.0
        dx[i] = 100 * abs(pdi - mdi) / (pdi + mdi) if (pdi + mdi) != 0 else 0.0

    start = period * 2
    out[start] = dx[period + 1:start + 1].mean()
    for i in range(start + 1, n):
        out[i] = (out[i - 1] * (period - 1) + dx[i]) / period
    return out


def bollinger(close: np.ndarray, period: int = 20, dev: float = 2.0):
    n = len(close)
    upper = np.full(n, np.nan, dtype=float)
    lower = np.full(n, np.nan, dtype=float)
    for i in range(period - 1, n):
        w = close[i - period + 1:i + 1]
        m = w.mean()
        s = w.std()
        upper[i] = m + dev * s
        lower[i] = m - dev * s
    return upper, lower


# ==================================================================
#                    STRATEGIYA SIGNALLARI
# ==================================================================
# Signal oxirgi YOPILGAN bar bo'yicha hisoblanadi (indeks -2).
# Kesishuv (cross) uchun -2 va -3 taqqoslanadi.

def compute_signal(strategy: str, rates) -> str | None:
    close = rates['close'].astype(float)
    high = rates['high'].astype(float)
    low = rates['low'].astype(float)

    if len(close) < 210:
        return None

    c = -2  # oxirgi yopilgan bar
    p = -3  # undan oldingi

    if strategy == "RSI_REVERSAL":
        r = rsi(close, 14)
        if r[c] < 30: return "BUY"
        if r[c] > 70: return "SELL"

    elif strategy == "SCALP_RSI":
        r = rsi(close, 7)
        if r[c] < 25: return "BUY"
        if r[c] > 75: return "SELL"

    elif strategy == "MA_CROSSOVER":
        f = ema(close, 50); s = ema(close, 200)
        if f[p] <= s[p] and f[c] > s[c]: return "BUY"
        if f[p] >= s[p] and f[c] < s[c]: return "SELL"

    elif strategy == "SCALP_MA":
        f = ema(close, 5); s = ema(close, 20)
        if f[p] <= s[p] and f[c] > s[c]: return "BUY"
        if f[p] >= s[p] and f[c] < s[c]: return "SELL"

    elif strategy == "MACD_CROSS":
        m, sig = macd(close)
        if m[p] <= sig[p] and m[c] > sig[c]: return "BUY"
        if m[p] >= sig[p] and m[c] < sig[c]: return "SELL"

    elif strategy == "BOLLINGER_BOUNCE":
        up, lo = bollinger(close, 20, 2.0)
        if close[c] < lo[c]: return "BUY"
        if close[c] > up[c]: return "SELL"

    elif strategy == "STOCHASTIC":
        k = stochastic_k(high, low, close, 5, 3)
        if k[c] < 20: return "BUY"
        if k[c] > 80: return "SELL"

    elif strategy == "SCALP_STOCH":
        k = stochastic_k(high, low, close, 5, 3)
        if k[c] < 15: return "BUY"
        if k[c] > 85: return "SELL"

    elif strategy == "CCI":
        cc = cci(high, low, close, 14)
        if cc[c] < -100: return "BUY"
        if cc[c] > 100: return "SELL"

    elif strategy == "TREND_FOLLOWING":
        ma = ema(close, 100)
        ad = adx(high, low, close, 14)
        if close[c] > ma[c] and ad[c] > 25: return "BUY"
        if close[c] < ma[c] and ad[c] > 25: return "SELL"

    return None


# ==================================================================
#                    SAVDO OPERATSIYALARI
# ==================================================================

def _normalize_lot(info, lot: float) -> float:
    step = info.volume_step or 0.01
    lot = round(lot / step) * step
    lot = max(info.volume_min, min(info.volume_max, lot))
    return round(lot, 2)


def _filling_type(info):
    """Symbol uchun mos filling turi"""
    mode = info.filling_mode
    if mode & 1:   # SYMBOL_FILLING_FOK
        return mt5.ORDER_FILLING_FOK
    if mode & 2:   # SYMBOL_FILLING_IOC
        return mt5.ORDER_FILLING_IOC
    return mt5.ORDER_FILLING_RETURN


def _close_position(pos) -> None:
    tick = mt5.symbol_info_tick(pos.symbol)
    if tick is None:
        return
    price = tick.bid if pos.type == mt5.POSITION_TYPE_BUY else tick.ask
    info = mt5.symbol_info(pos.symbol)
    req = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": pos.symbol,
        "volume": pos.volume,
        "type": mt5.ORDER_TYPE_SELL if pos.type == mt5.POSITION_TYPE_BUY else mt5.ORDER_TYPE_BUY,
        "position": pos.ticket,
        "price": price,
        "deviation": 30,
        "magic": MAGIC,
        "comment": "FUSION_BOT close",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": _filling_type(info) if info else mt5.ORDER_FILLING_IOC,
    }
    mt5.order_send(req)


def _open_trade(symbol: str, direction: str, lot: float, sl_pts: int, tp_pts: int) -> tuple[bool, str]:
    info = mt5.symbol_info(symbol)
    tick = mt5.symbol_info_tick(symbol)
    if info is None or tick is None:
        return False, "symbol ma'lumoti yo'q"

    point = info.point
    digits = info.digits
    lot = _normalize_lot(info, lot)

    if direction == "BUY":
        price = tick.ask
        sl = round(price - sl_pts * point, digits) if sl_pts > 0 else 0.0
        tp = round(price + tp_pts * point, digits) if tp_pts > 0 else 0.0
        otype = mt5.ORDER_TYPE_BUY
    else:
        price = tick.bid
        sl = round(price + sl_pts * point, digits) if sl_pts > 0 else 0.0
        tp = round(price - tp_pts * point, digits) if tp_pts > 0 else 0.0
        otype = mt5.ORDER_TYPE_SELL

    base_req = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": lot,
        "type": otype,
        "price": price,
        "sl": sl,
        "tp": tp,
        "deviation": 30,
        "magic": MAGIC,
        "comment": "FUSION_BOT",
        "type_time": mt5.ORDER_TIME_GTC,
    }

    # Bir nechta filling turini sinash (broker qo'llab-quvvatlaydiganini topish)
    fillings = [_filling_type(info), mt5.ORDER_FILLING_IOC,
                mt5.ORDER_FILLING_FOK, mt5.ORDER_FILLING_RETURN]
    seen = []
    last_err = ""
    for fill in fillings:
        if fill in seen:
            continue
        seen.append(fill)
        req = dict(base_req)
        req["type_filling"] = fill
        result = mt5.order_send(req)
        if result is None:
            last_err = f"order_send None: {mt5.last_error()}"
            continue
        if result.retcode == mt5.TRADE_RETCODE_DONE:
            return True, ""
        # 10030 = qo'llab-quvvatlanmaydigan filling — boshqasini sinaymiz
        if result.retcode == 10030:
            last_err = "filling mode qo'llab-quvvatlanmaydi"
            continue
        last_err = f"retcode {result.retcode}"
        break
    return False, last_err


# ==================================================================
#          BITTA FOYDALANUVCHI UCHUN SAVDO TSIKLI (sync)
#   Bu funksiya mt5_bridge._mt5_lock ostida chaqirilishi kerak.
#   Qaytaradi: foydalanuvchiga yuboriladigan xabarlar ro'yxati.
# ==================================================================

def _resolve_symbol(requested: str) -> str | None:
    """
    So'ralgan symbol nomini brokerdagi haqiqiy nomga moslashtirish.
    Masalan XAUUSD -> XAUUSDm / XAUUSD.r / XAUUSDz (broker suffikslari).
    """
    if not requested:
        return None
    req = requested.upper()

    # 1) Aniq mos kelsa
    info = mt5.symbol_info(requested)
    if info is not None:
        mt5.symbol_select(requested, True)
        return requested

    all_syms = mt5.symbols_get()
    if not all_syms:
        return None

    # 2) Katta-kichik harfsiz aniq moslik
    for s in all_syms:
        if s.name.upper() == req:
            mt5.symbol_select(s.name, True)
            return s.name
    # 3) Boshi mos (suffiksli: XAUUSDm, XAUUSD.r ...)
    for s in all_syms:
        if s.name.upper().startswith(req):
            mt5.symbol_select(s.name, True)
            return s.name
    # 4) Ichida mavjud
    for s in all_syms:
        if req in s.name.upper():
            mt5.symbol_select(s.name, True)
            return s.name
    return None


def trade_once_for_user(user: dict, settings: dict) -> list:
    events = []
    login = user.get("mt5_login")
    server = user.get("mt5_server")
    password = user.get("mt5_password")
    if not login:
        return events

    ok, err = mt5_bridge.login_account(login, server, password)
    if not ok:
        logger.warning(f"User {user['user_id']}: MT5 ulanish xatosi: {err}")
        return events

    requested = settings.get("symbol") or "EURUSD"
    tf = TF_MAP.get(settings.get("timeframe", "M5"), mt5.TIMEFRAME_M5)
    strategy = user.get("strategy", "RSI_REVERSAL")

    symbol = _resolve_symbol(requested)
    if symbol is None:
        logger.warning(f"User {user['user_id']}: symbol topilmadi: {requested}")
        return events

    rates = mt5.copy_rates_from_pos(symbol, tf, 0, 500)
    if rates is None or len(rates) < 210:
        return events

    # Yangi bar tekshiruvi (har barda bir marta)
    closed_time = int(rates[-2]['time'])
    key = user["user_id"]
    if _last_bar.get(key) == (symbol, tf, closed_time):
        return events
    _last_bar[key] = (symbol, tf, closed_time)

    signal = compute_signal(strategy, rates)

    # Mavjud pozitsiyalar (shu symbol + magic)
    positions = mt5.positions_get(symbol=symbol) or []
    mine = [pp for pp in positions if pp.magic == MAGIC]

    # Qarama-qarshi signalda mavjud pozitsiyani yopish
    if signal == "BUY":
        for pp in mine:
            if pp.type == mt5.POSITION_TYPE_SELL:
                _close_position(pp)
                events.append(f"⏹ {symbol} SELL yopildi (qarama-qarshi signal)")
    elif signal == "SELL":
        for pp in mine:
            if pp.type == mt5.POSITION_TYPE_BUY:
                _close_position(pp)
                events.append(f"⏹ {symbol} BUY yopildi (qarama-qarshi signal)")

    # Qayta tekshirish — hali ochiq pozitsiya bo'lsa yangi savdo ochilmaydi
    positions = mt5.positions_get(symbol=symbol) or []
    mine = [pp for pp in positions if pp.magic == MAGIC]
    if len(mine) > 0:
        return events

    if signal is None:
        return events

    lot = float(settings.get("lot", 0.10))
    sl_pts = int(settings.get("sl", 300))
    tp_pts = int(settings.get("tp", 600))

    ok, err = _open_trade(symbol, signal, lot, sl_pts, tp_pts)
    if ok:
        events.append(f"✅ {signal} {symbol} ochildi | lot {lot} | SL {sl_pts} | TP {tp_pts}")
        logger.info(f"User {user['user_id']}: {signal} {symbol} ochildi")
    else:
        events.append(f"⚠️ {symbol} {signal} ochilmadi: {err}")
        logger.warning(f"User {user['user_id']}: savdo ochish xatosi: {err}")

    return events
