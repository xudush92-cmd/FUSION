# FUSION Loyihasi — Kiro Qoidalari

## Loyiha haqida

FUSION — MetaTrader 5 uchun to'liq sozlanadigan savdo roboti (Expert Advisor) va uni Telegram orqali boshqarish boti.

**Komponentlar:**
- `MQL5/Experts/FUSION/FUSION.mq5` — MetaTrader 5 Expert Advisor (savdo logikasi)
- `FUSION_BOT/` — Python Telegram bot (boshqaruv paneli)

**Texnologiyalar:**
- MQL5 (MetaTrader 5 platformasi uchun)
- Python 3.10+ (async)
- aiogram 3.x (Telegram Bot Framework)
- aiosqlite (async SQLite)
- MetaTrader5 Python API
- cryptography (Fernet shifrlash)

---

## Kodlash qoidalari

### Umumiy
- Barcha izohlar, o'zgaruvchi nomlari va foydalanuvchiga ko'rinadigan matnlar **o'zbek tilida** bo'lishi kerak
- Kod ichidagi texnik nomlar (funksiya, klass, modul) **ingliz tilida** yoziladi
- Har bir fayl boshida `"""docstring"""` bilan modul tavsifi bo'lsin
- Type hints ishlatilsin (Python 3.10+ syntax: `dict | None`, `list[dict]`)

### Python (FUSION_BOT)
- Async/await uslubida yozilsin (sinxron koddan qochish)
- `aiogram 3.x` FSM (Finite State Machine) callback pattern ishlatilsin
- Database operatsiyalari `aiosqlite` bilan async bo'lsin
- Konfiguratsiya faqat `config.py` orqali — environment variables (`.env`) dan o'qilsin
- Parollar **hech qachon ochiq matn** sifatida saqlanmasin — `cryptography.fernet` bilan shifrlansin
- Har bir handler funksiyasida ruxsatni tekshirish (`is_admin()` yoki `get_user()`)

### MQL5 (Expert Advisor)
- `#property strict` direktivasi har doim mavjud bo'lsin
- Input parametrlar `input group` bilan guruhlansin
- Magic Number har doim tekshirilsin (faqat o'z pozitsiyalarini boshqarish)
- Indikator handle'lari to'g'ri bo'shatilsin (`IndicatorRelease`)
- CTrade, CPositionInfo, CSymbolInfo standart kutubxonalari ishlatilsin

---

## Arxitektura qoidalari

### Fayl tuzilishi
```
FUSION/
├── .kiro/steering/          ← Kiro qoidalari
├── MQL5/Experts/FUSION/     ← Expert Advisor
│   ├── FUSION.mq5
│   └── presets/             ← Tayyor .set fayllar
├── FUSION_BOT/              ← Telegram Bot
│   ├── fusion_bot.py        ← Handlerlar va main
│   ├── mt5_bridge.py        ← MT5 API bridge
│   ├── database.py          ← DB operatsiyalari
│   ├── keyboards.py         ← InlineKeyboard
│   ├── config.py            ← Konfiguratsiya
│   ├── crypto_utils.py      ← Shifrlash utilitalari
│   └── requirements.txt     ← Dependencies
└── docs/                    ← Dokumentatsiya
```

### Modullar orasidagi aloqa
- `fusion_bot.py` → `database.py` (foydalanuvchi ma'lumotlari)
- `fusion_bot.py` → `mt5_bridge.py` (savdo operatsiyalari)
- `fusion_bot.py` → `keyboards.py` (UI tugmalar)
- `mt5_bridge.py` → MetaTrader5 API (tashqi tizim)
- `config.py` ← `.env` fayl (sirlar)
- `crypto_utils.py` ← `database.py`, `mt5_bridge.py` (parol shifrlash/deshifrlash)

### Yangi funksiya qo'shish tartibi
1. Agar DB o'zgarishi kerak → `database.py` ga migration qo'shish
2. MT5 bilan bog'liq → `mt5_bridge.py` ga funksiya qo'shish
3. UI kerak → `keyboards.py` ga tugma qo'shish
4. Handler → `fusion_bot.py` ga FSM state + callback handler qo'shish

---

## Xavfsizlik qoidalari

- MT5 parollari `cryptography.fernet.Fernet` bilan shifrlanib saqlansin
- Shifrlash kaliti `.env` dagi `ENCRYPTION_KEY` dan olinsin
- Admin tekshiruvi har bir admin handlerda bo'lsin
- Foydalanuvchi `status == "active"` ekanligini har safar tekshirish
- Parol o'z ichiga olgan xabarlar (`message.delete()`) bilan o'chirilsin
- `.env` fayl `.gitignore` da bo'lsin (hech qachon commit qilinmasin)
- Database fayl (`fusion_bot.db`) `.gitignore` da bo'lsin

---

## Error Handling qoidalari

- MT5 ulanish xatolari foydalanuvchiga tushunarli xabar bilan qaytarilsin
- `try/except` bloklari aniq exception turlarini ushlashsin (bare `except:` ishlatilmasin)
- Xatolar `logger.error()` bilan log qilinsin
- Foydalanuvchiga texnik xato tafsilotlari ko'rsatilmasin — faqat umumiy xabar + yechim taklifi

---

## Git qoidalari

- Branch nomlari: `feature/...`, `fix/...`, `refactor/...`
- Commit xabarlari o'zbek tilida, qisqa va aniq
- `main` branch'ga to'g'ridan-to'g'ri push qilinmasin
- Har bir o'zgarish PR orqali kiritilsin
