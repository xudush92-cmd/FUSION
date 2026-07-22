"""
FUSION Bot — EA (MQL5 robot) bilan bog'lanish (fayl orqali)

Bot foydalanuvchi sozlamalarini MT5 ning "Common\\Files" papkasiga
FUSION_<login>.txt fayliga yozadi. MQL5 dagi FUSION EA shu faylni
o'qib, strategiya/timeframe/lot/SL/TP/risk ni qo'llaydi.

MUHIM: EA da "InpUseBotControl = true" bo'lishi kerak, aks holda
EA fayl buyruqlarini e'tiborsiz qoldiradi va o'z Inputs bilan ishlaydi.
"""
import os
import logging

logger = logging.getLogger("EA_BRIDGE")


def common_files_dir() -> str:
    """MT5 ning umumiy (Common) Files papkasi yo'li (Windows)"""
    appdata = os.getenv("APPDATA", "")
    return os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files")


def _bridge_file_path(login: int) -> str:
    return os.path.join(common_files_dir(), f"FUSION_{login}.txt")


def write_command(
    login: int,
    running: bool,
    strategy: str,
    settings: dict,
    engine: str = "PYTHON",
) -> tuple[bool, str]:
    """
    EA uchun buyruq faylini atomik yozish.
    Qaytaradi: (muvaffaqiyat, xato_xabari).

    engine=PYTHON bo'lsa EA InpUseBotControl o'chirilgan bo'lsa ham
    savdoni bloklaydi; engine=EA bo'lsa odatdagi enabled holatini qo'llaydi.
    """
    if not login:
        return False, "MT5 login yo'q"

    engine = engine.strip().upper()
    if engine not in {"PYTHON", "EA"}:
        return False, "Savdo dvigateli faqat PYTHON yoki EA bo'lishi mumkin"

    directory = common_files_dir()
    try:
        os.makedirs(directory, exist_ok=True)
    except Exception as e:
        logger.error(f"Common Files papkasini yaratib bo'lmadi: {e}")
        return False, f"Papka xatosi: {e}"

    lines = [
        f"engine={engine}",
        f"enabled={1 if running else 0}",
        f"strategy={strategy}",
        f"symbol={settings.get('symbol', '')}",
        f"timeframe={settings.get('timeframe', 'M5')}",
        f"lot={settings.get('lot', 0.10)}",
        f"sl={int(settings.get('sl', 300))}",
        f"tp={int(settings.get('tp', 600))}",
        f"risk={settings.get('risk', 1.0)}",
    ]
    content = "\n".join(lines) + "\n"

    path = _bridge_file_path(login)
    temp_path = f"{path}.tmp"
    try:
        with open(temp_path, "w", encoding="utf-8") as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temp_path, path)
        # DEBUG darajada: bu fayl har savdo tsiklida (5s) qayta yoziladi,
        # INFO bo'lsa log to'lib ketadi. Guard baribir ishlayveradi.
        logger.debug(f"EA buyruq fayli yozildi: {path}")
        return True, ""
    except Exception as e:
        try:
            if os.path.exists(temp_path):
                os.remove(temp_path)
        except OSError:
            pass
        logger.error(f"EA buyruq faylini yozib bo'lmadi: {e}")
        return False, f"Fayl yozish xatosi: {e}"


def clear_command(login: int) -> None:
    """EA buyruq faylini o'chirish (foydalanuvchi olib tashlanganda)"""
    if not login:
        return
    path = _bridge_file_path(login)
    try:
        if os.path.exists(path):
            os.remove(path)
            logger.info(f"EA buyruq fayli o'chirildi: {path}")
    except Exception as e:
        logger.debug(f"EA buyruq faylini o'chirib bo'lmadi: {e}")
