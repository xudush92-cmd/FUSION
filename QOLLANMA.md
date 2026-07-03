# FUSION Robot — To'liq Qo'llanma

Bu qo'llanma robot qanday savdo qilishini, indikatorlardan qanday foydalanishini
va har bir strategiya qaysi timeframega mos kelishini tushuntiradi.

---

## 1. Robot qanday ishlaydi (umumiy)

FUSION — Telegram bot orqali boshqariladigan avtomatik savdo roboti.
Robot MT5 (MetaTrader 5) ga ulanadi, narx ma'lumotlarini oladi, indikatorlarni
hisoblaydi va strategiya sharti bajarilса savdo ochadi.

**Savdo tsikli (har 15 soniyada takrorlanadi):**

1. MT5 dan oxirgi 500 ta shamni (bar) oladi
2. Tanlangan strategiya indikatorini hisoblaydi
3. **Yangi bar** ochilganda signal tekshiradi (har barda bir marta)
4. Signal bo'lsa va limit to'lmagan bo'lsa — savdo ochadi
5. Ochilgan savdoga SL (Stop Loss) va TP (Take Profit) qo'yadi
6. Savdo SL yoki TP ga yetguncha ochiq turadi

**Muhim tamoyillar:**
- Signal **oxirgi yopilgan bar** bo'yicha hisoblanadi (shoshilinch emas)
- Bir vaqtda "Maks. savdo soni" gacha savdo ochiladi
- Ochiq savdo SL/TP ga yetguncha yopilmaydi
- Har savdo o'z yakuniga yetadi (qarama-qarshi signalda yopilmaydi)

---

## 2. Robot nimaga asoslanib savdoga kiradi

Robot 2 xil mantiqdan foydalanadi:

### A) Reversal (qaytish) — "arzonda ol, qimmatda sot"
Narx juda pasayganda BUY, juda ko'tarilganda SELL. Narx "haddan tashqari"
holatdan qaytishini kutadi.
- Ishlatadigan strategiyalar: RSI, Stochastic, CCI, Bollinger
- Yon (flat) bozorda yaxshi ishlaydi

### B) Trend (yo'nalish) — "yo'nalish bo'yicha bor"
Narx ko'tarilsa BUY, tushsa SELL. Kuchli harakat yo'nalishini kuzatadi.
- Ishlatadigan strategiyalar: MA Crossover, MACD, Trend Following
- Trendli (yo'nalishli) bozorda yaxshi ishlaydi

---

## 3. O'rnatilgan indikatorlar

### RSI (Relative Strength Index)
- **Nima:** Narxning "haddan tashqari sotib olingan/sotilgan" holatini o'lchaydi (0-100)
- **Signal:** RSI < 30 → BUY (oversold), RSI > 70 → SELL (overbought)
- **Turi:** Reversal
- **Mos timeframe:** M5, M15, M30

### Moving Average (MA / EMA)
- **Nima:** O'rtacha narx chizig'i. Tez va sekin MA kesishuvi trend o'zgarishini ko'rsatadi
- **Signal:** Tez MA sekin MA ni yuqoriga kesса → BUY (golden cross), pastga kesса → SELL (death cross)
- **Turi:** Trend
- **Mos timeframe:** M15, H1, H4, D1

### MACD (Moving Average Convergence Divergence)
- **Nima:** Ikki MA farqi asosida momentum (tezlik) o'lchaydi
- **Signal:** MACD chizig'i signal chizig'ini yuqoriga kesса → BUY, pastga → SELL
- **Turi:** Trend / Momentum
- **Mos timeframe:** M15, H1, H4

### Stochastic
- **Nima:** Narxning oxirgi diapazondagi o'rnini o'lchaydi (0-100)
- **Signal:** < 20 → BUY (oversold), > 80 → SELL (overbought)
- **Turi:** Reversal
- **Mos timeframe:** M5, M15, M30

### CCI (Commodity Channel Index)
- **Nima:** Narxning o'rtachadan chetlanishini o'lchaydi
- **Signal:** < -100 → BUY, > +100 → SELL
- **Turi:** Reversal
- **Mos timeframe:** M15, M30, H1

### ADX (Average Directional Index)
- **Nima:** Trend KUCHINI o'lchaydi (yo'nalish emas). 0-100
- **Signal:** ADX > 25 → trend kuchli (filtr sifatida ishlatiladi)
- **Turi:** Filtr (Trend Following ichida)
- **Mos timeframe:** H1, H4, D1

### Bollinger Bands
- **Nima:** Narx atrofida yuqori/pastki chegara chiziqlari
- **Signal:** Narx pastki chiziqdan past → BUY, yuqori chiziqdan yuqori → SELL
- **Turi:** Reversal (mean reversion)
- **Mos timeframe:** M15, M30, H1

---

## 4. Tayyor strategiyalar

| Strategiya | Indikator | BUY sharti | SELL sharti | Turi | Mos TF |
|-----------|-----------|-----------|-------------|------|--------|
| RSI Reversal | RSI(14) | < 30 | > 70 | Reversal | M5-M30 |
| Skalp RSI | RSI(7) | < 25 | > 75 | Reversal | M1, M5 |
| MA Crossover | EMA(50/200) | tez yuqoriga kesса | tez pastga kesса | Trend | H1-D1 |
| Skalp MA | EMA(5/20) | tez yuqoriga kesса | tez pastga kesса | Trend | M1, M5 |
| MACD Cross | MACD(12,26,9) | main signalni yuqoriga | main signalni pastga | Trend | M15-H4 |
| Bollinger Bounce | BB(20) | narx pastki chiziqda | narx yuqori chiziqda | Reversal | M15-H1 |
| Stochastic | Stoch(5) | < 20 | > 80 | Reversal | M5-M30 |
| Skalp Stochastic | Stoch(5) | < 15 | > 85 | Reversal | M1, M5 |
| CCI | CCI(14) | < -100 | > +100 | Reversal | M15-H1 |
| Trend Following | MA(100)+ADX | narx MA dan yuqori + ADX>25 | narx MA dan past + ADX>25 | Trend | H1-D1 |

---

## 5. Timeframe tanlash

| Timeframe | Uslub | Signal chastotasi | Kimga mos |
|-----------|-------|-------------------|-----------|
| M1 | Skalping | Juda ko'p | Tez savdo, doim kuzatish |
| M5 | Skalping / qisqa | Ko'p | Faol savdo |
| M15 | Qisqa-o'rta | O'rtacha | Muvozanatli |
| M30 | O'rta | O'rtacha | Muvozanatli |
| H1 | Kunlik | Kam | Barqaror, kam savdo |
| H4 | Swing | Juda kam | Uzoq muddatli |
| D1 | Pozitsion | Eng kam | Uzoq muddatli |

**Qoida:** Kichik TF (M1, M5) → ko'p signal, ko'p "shovqin", ko'p risk.
Katta TF (H1+) → kam signal, barqaror, ishonchli.

---

## 6. Sozlamalar

| Sozlama | Nima |
|---------|------|
| Juftlik (Symbol) | Qaysi juftlikda savdo (XAUUSD, EURUSD...) |
| Lot | Savdo hajmi (masalan 0.10) |
| Stop Loss | Maksimal zarar masofasi (punkt) |
| Take Profit | Maqsad foyda masofasi (punkt) |
| Risk % | (hozircha lot bilan ishlaydi) |
| Maks. savdo soni | Bir vaqtda nechta savdo (1-10) |
| Timeframe | Signal hisoblash timeframi |
| Qo'lda ochilganga SL/TP | Qo'lda ochilgan savdolarga ham SL/TP qo'yish |

---

## 7. Tavsiyalar

**Boshlovchilar uchun (demo):**
- Strategiya: RSI Reversal yoki Trend Following
- Timeframe: M15
- Maks. savdo soni: 2
- SL/TP: TP > SL (masalan SL 300, TP 600) — oltinda kattaroq

**Skalping (faol) uchun:**
- Strategiya: Skalp RSI / Skalp Stochastic
- Timeframe: M5 (M1 juda tez)
- Kichik SL/TP, past spread hisob kerak

**Oltin (XAUUSD) uchun:**
- SL/TP ni KATTA qo'ying (oltin tez harakatlanadi)
- Masalan SL 3000-5000, TP 6000-10000 (broker punktiga qarab)

---

## 8. Muhim ogohlantirishlar

- Hech qanday robot foyda KAFOLATLAMAYDI
- Signal — bu faqat "ehtimol", bozor har doim mantiqqa bo'ysunmaydi
- Avval DEMO hisobda kamida 1-2 hafta sinang
- Real hisobga o'tishda kichik lot bilan boshlang
- Risk boshqaruvi: bir savdoda balansning 1-2% dan ortiq risk qilmang
