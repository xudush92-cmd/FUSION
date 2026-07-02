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
import time
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

# Bir xil xato xabarini takror yubormaslik uchun (user_id -> (xabar, vaqt))
_last_error: dict = {}
ERROR_REPEAT_SEC = 600  # bir xil xato 10 daqiqada bir marta xabar qilinadi


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

    # Brokerning minimal stop masofasi (punktda). SL/TP shundan yaqin bo'lolmaydi.
    stops_level = getattr(info, "trade_stops_level", 0) or 0
    freeze_level = getattr(info, "trade_freeze_level", 0) or 0
    min_dist = max(stops_level, freeze_level)
    # Foydalanuvchi qiymatini hurmat qilamiz, lekin brokerning minimalidan past bo'lolmaydi
    buffer = max(min_dist, 1)
    if sl_pts > 0 and sl_pts < buffer:
        sl_pts = buffer
    if tp_pts > 0 and tp_pts < buffer:
        tp_pts = buffer

    if direction == "BUY":
        otype = mt5.ORDER_TYPE_BUY
        price = tick.ask
    else:
        otype = mt5.ORDER_TYPE_SELL
        price = tick.bid

    # 1-QADAM: Bozor buyrug'ini SL/TP SIZ ochish (10016 xatosining oldini oladi)
    base_req = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": lot,
        "type": otype,
        "price": price,
        "deviation": 30,
        "magic": MAGIC,
        "comment": "FUSION_BOT",
        "type_time": mt5.ORDER_TIME_GTC,
    }

    fillings = [_filling_type(info), mt5.ORDER_FILLING_IOC,
                mt5.ORDER_FILLING_FOK, mt5.ORDER_FILLING_RETURN]
    seen = []
    last_err = ""
    opened = False
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
            opened = True
            break
        if result.retcode == 10030:  # filling qo'llab-quvvatlanmaydi
            last_err = "filling mode qo'llab-quvvatlanmaydi"
            continue
        last_err = _retcode_message(result.retcode)
        break

    if not opened:
        return False, last_err

    # 2-QADAM: Ochilgan pozitsiyaga SL/TP qo'yish (best-effort)
    if sl_pts > 0 or tp_pts > 0:
        _apply_sltp(symbol, direction, sl_pts, tp_pts, point, digits)

    return True, ""


def _apply_sltp(symbol, direction, sl_pts, tp_pts, point, digits):
    """Eng oxirgi ochilgan pozitsiyaga SL/TP qo'yish (alohida so'rov)."""
    positions = mt5.positions_get(symbol=symbol) or []
    mine = [p for p in positions if p.magic == MAGIC]
    if not mine:
        return
    # Eng yangi pozitsiyani vaqt bo'yicha tanlash
    pos = max(mine, key=lambda p: getattr(p, "time_msc", p.time))
    _set_position_sltp(pos, direction, sl_pts, tp_pts, point, digits)


def _ensure_sltp(symbol: str, sl_pts: int, tp_pts: int) -> int:
    """
    Ochiq savdolarni tekshirib, SL/TP si yo'qlariga qo'yadi.
    Bu savdolarning SL/TP orqali yopilishini kafolatlaydi.
    Qaytaradi: tuzatilgan savdolar soni.
    """
    info = mt5.symbol_info(symbol)
    if info is None:
        return 0
    point = info.point
    digits = info.digits
    positions = mt5.positions_get(symbol=symbol) or []
    mine = [p for p in positions if p.magic == MAGIC]
    fixed = 0
    for pos in mine:
        need_sl = (pos.sl == 0.0 and sl_pts > 0)
        need_tp = (pos.tp == 0.0 and tp_pts > 0)
        if need_sl or need_tp:
            direction = "BUY" if pos.type == mt5.POSITION_TYPE_BUY else "SELL"
            if _set_position_sltp(pos, direction, sl_pts, tp_pts, point, digits):
                fixed += 1
    return fixed


def _set_position_sltp(pos, direction, sl_pts, tp_pts, point, digits) -> bool:
    """Berilgan pozitsiyaga SL/TP qo'yish (broker minimal masofa + spread, xatoda qayta urinish)."""
    info = mt5.symbol_info(pos.symbol)
    tick = mt5.symbol_info_tick(pos.symbol)
    if info is None or tick is None:
        return False

    stops_level = getattr(info, "trade_stops_level", 0) or 0
    freeze_level = getattr(info, "trade_freeze_level", 0) or 0
    spread = getattr(info, "spread", 0) or 0
    # Minimal masofa (punktda): broker limiti + spread + zaxira
    min_pts = max(stops_level, freeze_level) + spread + 5

    # Bir necha marta urinish — har safar masofani kattalashtirib (10016 uchun)
    for attempt in range(4):
        factor = 1 + attempt  # 1x, 2x, 3x, 4x
        sl_dist = max(sl_pts, min_pts) * factor * point if sl_pts > 0 else 0.0
        tp_dist = max(tp_pts, min_pts) * factor * point if tp_pts > 0 else 0.0

        if direction == "BUY":
            ref = tick.bid
            sl = round(ref - sl_dist, digits) if sl_dist > 0 else 0.0
            tp = round(ref + tp_dist, digits) if tp_dist > 0 else 0.0
        else:
            ref = tick.ask
            sl = round(ref + sl_dist, digits) if sl_dist > 0 else 0.0
            tp = round(ref - tp_dist, digits) if tp_dist > 0 else 0.0

        req = {
            "action": mt5.TRADE_ACTION_SLTP,
            "symbol": pos.symbol,
            "position": pos.ticket,
            "sl": sl,
            "tp": tp,
            "magic": MAGIC,
        }
        result = mt5.order_send(req)
        if result is not None and result.retcode == mt5.TRADE_RETCODE_DONE:
            return True
        # 10016 (noto'g'ri stop) bo'lsa masofani kattalashtirib qayta urinamiz
        code = result.retcode if result else "None"
        if code != 10016:
            logger.warning(f"SL/TP qo'yilmadi (ticket {pos.ticket}): retcode {code}")
            return False

    logger.warning(f"SL/TP qo'yilmadi (ticket {pos.ticket}): 10016 (masofa juda yaqin)")
    return False


def _retcode_message(code: int) -> str:
    """MT5 retcode ni tushunarli xabarga aylantirish"""
    messages = {
        10027: "AutoTrading o'chirilgan! MT5 terminalida 'Algo Trading' tugmasini yoqing.",
        10018: "Bozor yopiq (dam olish kuni yoki savdo vaqti emas).",
        10019: "Mablag' yetarli emas (balans/margin).",
        10016: "Noto'g'ri SL/TP darajasi (juda yaqin).",
        10014: "Noto'g'ri lot hajmi.",
        10006: "So'rov rad etildi (broker).",
        10004: "Rekvota (narx o'zgardi) — qayta urinadi.",
        10013: "Noto'g'ri so'rov.",
        10015: "Noto'g'ri narx.",
    }
    return messages.get(code, f"retcode {code}")


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

    sl_pts_cfg = int(settings.get("sl", 300))
    tp_pts_cfg = int(settings.get("tp", 600))

    # HAR TSIKLDA: ochiq savdolarda SL/TP borligini tekshirish.
    # Agar biror savdo SL/TP siz qolgan bo'lsa — qo'yamiz (yopilishini kafolatlash).
    fixed = _ensure_sltp(symbol, sl_pts_cfg, tp_pts_cfg)
    if fixed:
        events.append(f"🛠 {symbol}: {fixed} ta savdoga SL/TP qo'yildi")

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

    # Bir vaqtda ruxsat etilgan maksimal savdo soni (sozlamadan)
    max_pos = int(settings.get("max_pos", 1))
    if max_pos < 1:
        max_pos = 1

    # Ochiq savdolar SL/TP ga yetguncha yopilmaydi (churning yo'q).
    # Lekin limit to'lmagan bo'lsa, yangi signalда qo'shimcha savdo ochiladi
    # (qulay signal o'tkazib yuborilmaydi).
    if len(mine) >= max_pos:
        return events

    if signal is None:
        return events

    lot = float(settings.get("lot", 0.10))
    sl_pts = sl_pts_cfg
    tp_pts = tp_pts_cfg

    ok, err = _open_trade(symbol, signal, lot, sl_pts, tp_pts)
    if ok:
        # Savdo haqiqatan ochiq turganini tekshirish (soxta xabarning oldini olish)
        time.sleep(0.5)
        positions_after = mt5.positions_get(symbol=symbol) or []
        mine_after = [pp for pp in positions_after if pp.magic == MAGIC]
        if len(mine_after) > len(mine):
            events.append(f"✅ {signal} {symbol} ochildi | lot {lot} | SL {sl_pts} | TP {tp_pts}")
            logger.info(f"User {user['user_id']}: {signal} {symbol} ochildi")
        else:
            # Ochildi-yu darrov yopildi (SL/TP juda kichik yoki spread katta)
            events.append(
                f"⚠️ {symbol} {signal} ochildi, lekin DARROV yopildi!\n"
                f"Sabab: SL/TP juda kichik ({sl_pts}/{tp_pts}) yoki spread katta.\n"
                f"💡 Yechim: SL/TP ni oshiring (masalan 100+)."
            )
            logger.warning(f"User {user['user_id']}: savdo ochildi-yu darrov yopildi (SL={sl_pts} TP={tp_pts})")
        _last_error.pop(user["user_id"], None)  # xato holatini tozalash
    else:
        logger.warning(f"User {user['user_id']}: savdo ochish xatosi: {err}")
        # Bir xil xatoni takror yubormaslik (spam oldini olish)
        uid = user["user_id"]
        prev = _last_error.get(uid)
        now = time.time()
        if prev is None or prev[0] != err or (now - prev[1]) >= ERROR_REPEAT_SEC:
            _last_error[uid] = (err, now)
            events.append(f"⚠️ {symbol} {signal} ochilmadi: {err}")

    return events
