# FUSION EA

**Fully Unified System for Intelligent Order Navigation**

FUSION — MetaTrader 5 (kompyuter / Windows) uchun **trader o'zi qoida quradigan**, to'liq sozlanadigan savdo roboti (Expert Advisor). Robotda oldindan tayyor strategiya yo'q — savdo mantig'ini **trader o'zi sozlamalar orqali** belgilaydi.

> ⚠️ **Ogohlantirish:** Avtomatik savdo katta moliyaviy risk bilan bog'liq. Hech qanday robot foyda kafolatlamaydi. Avval **demo hisobda** va **Strategy Tester**da sinab ko'ring.

---

## Asosiy g'oya

Robot — bu "ijrochi". Trader nima desa, shuni qiladi:
- Trader **BUY** va **SELL** uchun shartlarni (conditions) quradi
- Har bir shart: `[Indikator A] [Operator] [Qiymat yoki Indikator B]`
- Shartlar **AND / OR / VOTING** mantig'i bilan birlashtiriladi
- Robot shu qoidalar bajarilganda savdo ochadi/yopadi

---

## O'rnatish (kompyuter)

1. MetaTrader 5 ni oching
2. `File → Open Data Folder` → `MQL5/Experts/` papkasini oching
3. Ushbu repodagi `MQL5/Experts/FUSION/` papkasini shu yerga ko'chiring
   (ya'ni natija: `.../MQL5/Experts/FUSION/FUSION.mq5`)
4. MT5 da `Navigator → Expert Advisors` → o'ng tugma → `Refresh`
5. `FUSION` ustiga ikki marta bosing (yoki MetaEditor'da `Compile` qiling)
6. Robotni kerakli grafik (chart) ustiga sudrab tashlang
7. Ochilgan **Inputs** oynasida sozlamalarni belgilang
8. Yuqori o'ng burchakda `Algo Trading` tugmasi yoqilganiga ishonch hosil qiling

---

## Sozlamalar (Inputs) bo'limlari

| Bo'lim | Nimani boshqaradi |
|--------|-------------------|
| **1. Umumiy / Texnik** | Magic Number, comment, slippage, bildirishnomalar |
| **2. Vaqt** | Savdo soatlari, kunlar, GMT offset, kun oxirida yopish |
| **3. Juftlik / Spread** | Maksimal ruxsat etilgan spread |
| **4. Timeframe** | Signal timeframe, har barda bitta savdo |
| **5. Lot / Foiz** | Qat'iy lot yoki risk %, maks. lot, maks. pozitsiya |
| **6. Stop Loss / Take Profit** | SL/TP (Fixed/ATR/Off), trailing, break-even |
| **7. Himoya / Limitlar** | Kunlik zarar/foyda, maks. drawdown |
| **8. BUY qoidalari** | 4 ta shart sloti + mantiq (trader quradi) |
| **9. SELL qoidalari** | 4 ta shart sloti + mantiq (trader quradi) |
| **10. Chiqish** | SL/TP, qarama-qarshi signal, yoki ikkalasi |

---

## Shart (Condition) qanday quriladi

Har bir BUY/SELL shart sloti quyidagilardan iborat:

- **On** — shart yoqilganmi (true/false)
- **IndA** — Indikator A: `Price, MA, RSI, MACD main, MACD signal, Stochastic, CCI, ADX, ATR, BB upper, BB lower`
- **PerA** — A indikator davri
- **Op** — Operator: `> (katta)`, `< (kichik)`, `Cross above`, `Cross below`
- **Cmp** — Taqqoslash: `Value (raqam)` yoki `Ind (boshqa indikator)`
- **Val** — taqqoslash qiymati (Cmp=Value bo'lsa)
- **IndB / PerB** — Indikator B (Cmp=Ind bo'lsa)

### Misol strategiyalar (trader o'zi sozlaydi)

**1. RSI reversal (standart):**
- BUY shart 1: `RSI(14) < 30`
- SELL shart 1: `RSI(14) > 70`
- Logic: AND

**2. MA crossover (trend):**
- BUY shart 1: `MA(50) Cross above MA(200)`
- SELL shart 1: `MA(50) Cross below MA(200)`
- Logic: AND

**3. Trend filtri bilan RSI:**
- BUY 1: `RSI(14) < 35`, BUY 2: `Price > MA(200)`
- Logic: AND (ikkalasi ham bajarilsa)

---

## Mantiq rejimlari (Logic)

- **AND** — barcha yoqilgan shartlar bajarilsa savdo ochiladi (kuchli signal)
- **OR** — bittasi bajarilsa yetarli (ko'p savdo)
- **VOTING** — kamida N ta shart bajarilsa (N = `VotesNeeded`)

---

## Risk boshqaruvi

- **LOT_FIXED** — har savdoda qat'iy lot
- **LOT_RISK_PERCENT** — balansning belgilangan %i risk qilinadi (SL masofasiga qarab lot avtomatik hisoblanadi)
- **Himoya:** kunlik zarar limiti, kunlik foyda maqsadi, umumiy drawdown limiti — yetilganda robot to'xtaydi

---

## Eslatma

- Robot faqat **kompyuter** (desktop MT5) yoki **VPS**da ishlaydi. Telefon ilovasida (MT5 mobile) Expert Advisorlar ishlamaydi.
- 24/7 uzluksiz ishlatish uchun VPS tavsiya etiladi.
- Bu loyiha boshqa loyihalardan **mustaqil** va alohida.
