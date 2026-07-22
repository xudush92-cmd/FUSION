# FUSION — Serverdagi (VPS) robotni yangilash

Bu qo'llanma jonli ishlab turgan FUSION robotini **xavfsiz** yangilash uchun.
Ochiq savdolar yopilmaydi, `.env` va foydalanuvchilar bazasi saqlanadi.

> ⚠️ **Eng muhim:** Yangilash paytida Telegram'dagi **STOP tugmasini BOSMANG** —
> u ochiq savdolarni yopib yuboradi. Robotni faqat quyidagi bosqichlar bo'yicha,
> Python jarayonini to'xtatib yangilang. Jarayonni to'xtatish ochiq savdolarga
> tegmaydi — ular MT5 da SL/TP gacha ochiq qoladi.

---

## 0-QADAM: Avval PR ni merge qiling

Yangi kod hozir GitHub'da Pull Request sifatida turibdi (branch:
`fix/strategy-signals-single-engine`).

1. GitHub'da PR sahifasini oching: **Pull Request #2**
2. **Merge pull request** tugmasini bosing
3. Endi `main` shohobchasida yangi kod turadi

Merge qilinmasa, quyidagi `git pull` eski kodni tortadi.

---

## 1-QADAM: Robotni to'xtatish (savdolarni yopmasdan)

VPS (Windows) da FUSION bot qanday ishga tushirilganiga qarab:

- **Oddiy oyna (python fusion_bot.py) bo'lsa:** o'sha oynada **Ctrl + C** bosing
  yoki oynani yoping.
- **Task Scheduler / NSSM xizmati bo'lsa:** xizmatni to'xtating
  (`services.msc` → FUSION xizmati → Stop, yoki `nssm stop FUSION`).

Bu faqat botni to'xtatadi. MT5 dagi ochiq savdolar joyida qoladi.

---

## 2-QADAM: Zaxira nusxa (backup)

Yangilashdan oldin muhim fayllarni zaxiralang. FUSION_BOT papkasida
`yangilash.bat` faylini ishga tushiring ( pastda) — yoki qo'lda nusxalang:

- `FUSION_BOT\.env`            → `.env.backup`
- `FUSION_BOT\fusion_bot.db`   → `fusion_bot.db.backup`

Bu fayllarda bot tokeni, admin ID, shifrlash kaliti va foydalanuvchilar bor.
**Ularni hech qachon o'chirmang va GitHub'ga yuklamang.**

---

## 3-QADAM: Yangi kodni olish

### Variant A — git pull (agar server git bilan sozlangan bo'lsa)

```
cd C:\path\to\FUSION
git stash
git pull origin main
git stash pop
```

### Variant B — ZIP yuklab olish (git yo'q bo'lsa)

1. GitHub'da FUSION repo → **Code → Download ZIP**
2. ZIP ni oching
3. **Faqat kod fayllarini** eski papka ustiga ko'chiring:
   - `FUSION_BOT\` ichidagi barcha `.py` fayllar
   - `MQL5\` papkasi (EA ishlatilsa)
4. **`.env` va `fusion_bot.db` fayllariga TEGMANG** — eski holida qoldiring.

> `.env` va `fusion_bot.db` gitignore'da, shuning uchun git pull ularni
> o'zgartirmaydi. ZIP orqali yangilaganda ularni ustiga yozmang.

---

## 4-QADAM: `.env` ni tekshirish

`FUSION_BOT\.env` faylini oching va quyidagi qator borligiga ishonch hosil qiling:

```
TRADING_ENGINE=PYTHON
```

- Bu qator yo'q bo'lsa — qo'shing.
- Python bot savdo qilsa `PYTHON`, MT5 dagi EA savdo qilsa `EA` yozing.
- **Ikkalasini bir vaqtda ishlatmang** — bu bir signalga ikki marta savdo ochadi.

Qolgan qatorlar (BOT_TOKEN, ADMIN_IDS, ENCRYPTION_KEY, MT5_PATH) eski holida
qolishi kerak.

---

## 5-QADAM: Kutubxonalarni yangilash

```
cd C:\path\to\FUSION\FUSION_BOT
pip install -r requirements.txt
```

Yangi kod qo'shimcha kutubxona talab qilmaydi, lekin bu buyruq versiyalarni
tekshirib turadi.

---

## 6-QADAM: Robotni qayta ishga tushirish

- **Oddiy oyna:** `python fusion_bot.py`
- **Xizmat:** xizmatni Start qiling (`nssm start FUSION` yoki services.msc).

Ishga tushgach log'da quyidagi qatorlarni ko'rishingiz kerak:

```
Savdo dvigateli: PYTHON
FUSION Bot ishga tushdi...
```

`Savdo dvigateli: PYTHON` (yoki `EA`) qatori — yangi kod ishga tushganini
tasdiqlaydi.

---

## 7-QADAM: Tekshirish

1. Telegram'da botga `/start` yuboring — menyu ochilsin.
2. **Holat** va **Balans** tugmalarini bosing — MT5 ulanish ishlayotganini
   tekshiring.
3. Log'da xato yo'qligini ko'ring.
4. Ochiq savdolaringiz joyida turganiga ishonch hosil qiling.

---

## MQL5 EA ni ishlatsangiz (TRADING_ENGINE=EA)

1. Yangi `MQL5\Experts\FUSION\FUSION.mq5` ni MT5 ning Experts papkasiga ko'chiring.
2. MetaEditor (F4) → `FUSION.mq5` → **Compile (F7)** → "0 errors" chiqsin.
3. EA ni chartdan olib, qayta tashlang (yangi `.ex5` yuklanishi uchun).
4. `.set` presetni **Load** qiling (masalan `presets\01_RSI_Reversal.set`).

---

## Muammo bo'lsa — ortga qaytish (rollback)

1. Robotni to'xtating.
2. Zaxira fayllarni tiklang:
   - `.env.backup` → `.env`
   - `fusion_bot.db.backup` → `fusion_bot.db`
3. Kodni eski holatiga qaytaring:
   ```
   git checkout <eski_commit>
   ```
   yoki eski ZIP dan fayllarni tiklang.
4. Robotni qayta ishga tushiring.

---

## Xavfsizlik eslatmalari

- Avval **demo hisobda** yangi kodni sinash tavsiya etiladi.
- Yangilashni bozor **yopiq** paytda (masalan dam olish kuni) qilish xavfsizroq.
- Hech qanday robot foyda kafolatlamaydi — risk boshqaruvini o'chirib qo'ymang.
