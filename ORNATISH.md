# FUSION — Kompyuterga o'rnatish (oson qo'llanma)

Bu qo'llanma orqali FUSION robotini kompyuteringizdagi MetaTrader 5 ga **5 daqiqada** o'rnatasiz.

> Faqat **kompyuter (Windows)** uchun. Telefon ilovasida robotlar ishlamaydi.

---

## 1-QADAM: Faylni yuklab olish

1. GitHub sahifaga kiring: **https://github.com/xudush92-cmd/FUSION**
2. Yashil **`< > Code`** tugmasini bosing
3. **`Download ZIP`** ni tanlang
4. ZIP faylni kompyuterda **oching (extract)**
5. Ichidan `MQL5/Experts/FUSION/FUSION.mq5` faylini toping

---

## 2-QADAM: Faylni MT5 papkasiga qo'yish

1. MetaTrader 5 ni oching
2. Yuqori menyudan: **File → Open Data Folder** (Fayl → Ma'lumotlar papkasini ochish)
3. Ochilgan oynada: **MQL5 → Experts** papkasiga kiring
4. `FUSION.mq5` faylini (yoki butun `FUSION` papkasini) shu **Experts** papkasiga **ko'chiring (copy-paste)**

---

## 3-QADAM: Kompilyatsiya (eng muhim qadam!)

Robot ishlashi uchun `.mq5` fayl **kompilyatsiya** qilinishi kerak (.ex5 ga aylanadi).

1. MetaTrader 5 da **MetaEditor** ni oching:
   - Yo'l: yuqori panelda **IDE** tugmasi, yoki **F4** tugmasini bosing
2. Chap tomonda **Navigator -> Experts -> FUSION.mq5** ni toping
3. Ustiga **2 marta bosing** (ochiladi)
4. Yuqorida **Compile** tugmasini bosing (yoki **F7**)
5. Pastda **"0 errors, 0 warnings"** ko'rinsa — tayyor!

---

## 4-QADAM: Robotni ishga tushirish

1. MetaTrader 5 ga qaytib keling
2. Kerakli juftlik grafigini (chart) oching — masalan **EURUSD** yoki **XAUUSD**
3. Chap **Navigator -> Expert Advisors -> FUSION** ni toping
4. Uni **grafik ustiga sudrab tashlang** (drag & drop)
5. Ochilgan oynada:
   - **Common** bo'limida: **"Allow Algo Trading"** belgilangan bo'lsin
   - **Inputs** bo'limida: sozlamalarni o'zingizga moslang
6. **OK** bosing
7. Yuqori o'ng burchakda **"Algo Trading"** tugmasi **yashil** bo'lib turishi kerak

Grafik o'ng burchakda jilmaygan yuz belgisi chiqsa — robot ishlayapti!

---

## Muammolar va yechimlari

| Muammo | Yechim |
|--------|--------|
| Robot ishlamayapti | Yuqoridagi **"Algo Trading"** tugmasini yoqing (yashil bo'lsin) |
| "Compile" da xato chiqdi | MetaEditor versiyasi eski. MT5 ni yangilang |
| Navigator'da FUSION ko'rinmayapti | Navigator -> Expert Advisors -> o'ng tugma -> **Refresh** |
| Savdo ochmayapti | Inputs'da vaqt filtri (soat/kun) va shartlarni tekshiring |
| ".ex5" fayl yo'q | 3-qadamni (kompilyatsiya) bajardingizmi? |

---

## Birinchi marta uchun maslahat

1. **Avval DEMO hisobda sinab ko'ring** (real pul bilan emas!)
2. **Strategy Tester**da backtest qiling:
   - MT5 da **View -> Strategy Tester** (yoki Ctrl+R)
   - Expert: **FUSION**, juftlik va davrni tanlang
   - **Start** bosing — robot tarixiy ma'lumotda qanday ishlashini ko'rasiz
3. Tayyor sozlamani yuklash: Inputs oynasida **Load** -> `presets/01_RSI_Reversal.set` (yoki boshqa tayyor strategiya)

---

## Strategiya tanlash (2 rejim)

FUSION'da **Inputs -> "0. STRATEGIYA REJIMI"** bo'limida tanlaysiz:

- **PRESET** (tavsiya, oson): `InpPreset` dan tayyor strategiya tanlang
  (RSI, MA Crossover, MACD, Bollinger, Stochastic, CCI, Trend Following)
- **CUSTOM**: o'zingiz BUY/SELL shartlarini qurasiz (8 va 9-bo'limlar)

Eng oson yo'l — `presets/` papkasidagi tayyor `.set` fayllardan birini **Load** qilish.

---

## Qisqacha (juda tez)

```
1. ZIP yuklab oling -> oching
2. FUSION.mq5 -> MT5 "Experts" papkasiga ko'chiring
3. MetaEditor (F4) -> FUSION -> Compile (F7)
4. Grafikka sudrab tashlang -> Algo Trading yoqing -> OK
```

Tayyor!
