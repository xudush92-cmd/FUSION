@echo off
REM ============================================================
REM  FUSION bot - Windows VPS yangilash yordamchisi
REM  Bu skript: zaxira oladi, git pull qiladi, kutubxonalarni
REM  yangilaydi. Robotni O'ZI to'xtatmaydi/ishga tushirmaydi -
REM  buni siz qo'lda qilasiz (SERVERGA_YANGILASH.md ga qarang).
REM ============================================================

setlocal enabledelayedexpansion
cd /d "%~dp0"

echo.
echo === FUSION yangilash boshlandi ===
echo Papka: %cd%
echo.

REM --- Vaqt tamg'asi (backup nomi uchun) ---
for /f "tokens=1-4 delims=/.- " %%a in ("%date%") do set D=%%a-%%b-%%c
set T=%time::=-%
set T=%T: =0%
set STAMP=%D%_%T:~0,8%

REM --- 1) Zaxira: .env va fusion_bot.db ---
if exist ".env" (
    copy /Y ".env" ".env.backup_%STAMP%" >nul
    echo [OK] .env zaxiralandi: .env.backup_%STAMP%
) else (
    echo [OGOH] .env topilmadi - tekshiring!
)

if exist "fusion_bot.db" (
    copy /Y "fusion_bot.db" "fusion_bot.db.backup_%STAMP%" >nul
    echo [OK] fusion_bot.db zaxiralandi: fusion_bot.db.backup_%STAMP%
) else (
    echo [INFO] fusion_bot.db topilmadi ^(birinchi ishga tushish bo'lishi mumkin^)
)

echo.

REM --- 2) Yangi kodni olish (git bo'lsa) ---
where git >nul 2>nul
if %errorlevel%==0 (
    echo === git pull origin main ===
    cd ..
    git stash --include-untracked
    git pull origin main
    git stash pop
    cd "%~dp0"
    echo [OK] Kod git orqali yangilandi
) else (
    echo [INFO] git topilmadi. Kodni ZIP orqali qo'lda ko'chiring.
    echo         .env va fusion_bot.db ga TEGMANG.
)

echo.

REM --- 3) Kutubxonalarni yangilash ---
echo === pip install -r requirements.txt ===
pip install -r requirements.txt

echo.

REM --- 4) .env da TRADING_ENGINE borligini tekshirish ---
if exist ".env" (
    findstr /C:"TRADING_ENGINE" ".env" >nul
    if !errorlevel!==0 (
        echo [OK] .env da TRADING_ENGINE mavjud
    ) else (
        echo [OGOH] .env da TRADING_ENGINE YO'Q!
        echo         Quyidagi qatorni .env ga qo'shing:
        echo             TRADING_ENGINE=PYTHON
    )
)

echo.
echo === Tayyor ===
echo Endi robotni qayta ishga tushiring:
echo     python fusion_bot.py
echo.
echo Log'da "Savdo dvigateli: PYTHON" chiqsa - yangilash muvaffaqiyatli.
echo.
pause
endlocal
