//+------------------------------------------------------------------+
//|                                                       FUSION.mq5  |
//|        FUSION - Fully Unified System for Intelligent Order Nav.   |
//|        Trader o'zi qoida quradigan, to'liq sozlanadigan robot     |
//+------------------------------------------------------------------+
#property copyright "FUSION EA"
#property link      ""
#property version   "2.00"
#property description "FUSION - to'liq sozlanadigan MT5 robot. 2 rejim:"
#property description "PRESET (10 tayyor strategiya) yoki CUSTOM (trader o'zi qoida quradi)."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//==================================================================
//                         ENUMLAR (TANLOVLAR)
//==================================================================

// Indikator turlari (shart slotlarida tanlanadi)
enum ENUM_IND
{
   IND_NONE = 0,     // (bo'sh / ishlatilmaydi)
   IND_PRICE,        // Narx (Close)
   IND_MA,           // Moving Average
   IND_RSI,          // RSI
   IND_MACD_MAIN,    // MACD main liniya
   IND_MACD_SIGNAL,  // MACD signal liniya
   IND_STOCH,        // Stochastic (main)
   IND_CCI,          // CCI
   IND_ADX,          // ADX
   IND_ATR,          // ATR (qiymat)
   IND_BB_UPPER,     // Bollinger yuqori chiziq
   IND_BB_LOWER      // Bollinger pastki chiziq
};

// Operatorlar (shartni taqqoslash uchun)
enum ENUM_OP
{
   OP_GREATER = 0,   // > (katta)
   OP_LESS,          // < (kichik)
   OP_CROSS_ABOVE,   // yuqoriga kesib o'tdi
   OP_CROSS_BELOW    // pastga kesib o'tdi
};

// Taqqoslash maqsadi: raqamgami yoki boshqa indikatorgami
enum ENUM_CMP
{
   CMP_VALUE = 0,    // belgilangan raqam bilan
   CMP_IND           // boshqa indikator bilan
};

// Shartlarni birlashtirish mantig'i
enum ENUM_LOGIC
{
   LOGIC_AND = 0,    // hamma yoqilgan shart bajarilsa
   LOGIC_OR,         // birorta shart bajarilsa
   LOGIC_VOTING      // kamida N ta shart bajarilsa
};

// Lot rejimi
enum ENUM_LOTMODE
{
   LOT_FIXED = 0,    // qat'iy lot
   LOT_RISK_PERCENT  // balansdan risk foizi
};

// Stop Loss rejimi
enum ENUM_SLMODE
{
   SL_FIXED = 0,     // qat'iy punkt
   SL_ATR,           // ATR asosida
   SL_OFF            // SL ishlatilmaydi
};

// Chiqish rejimi
enum ENUM_EXITMODE
{
   EXIT_SLTP_ONLY = 0,    // faqat SL/TP
   EXIT_OPPOSITE_SIGNAL,  // qarama-qarshi signalda yopish
   EXIT_BOTH              // ikkalasi ham
};

// Strategiya rejimi: tayyor yoki maxsus
enum ENUM_STRATMODE
{
   STRAT_PRESET = 0,  // Tayyor strategiyadan foydalanish
   STRAT_CUSTOM       // O'zi qoida quradi (4+4 shart sloti)
};

// Tayyor strategiyalar ro'yxati (PRESET rejimida)
enum ENUM_PRESET
{
   PRESET_RSI_REVERSAL = 0, // RSI reversal (RSI<30 BUY, >70 SELL)
   PRESET_MA_CROSSOVER,     // MA crossover (tez/sekin MA kesishuvi)
   PRESET_MACD_CROSS,       // MACD crossover (main/signal kesishuvi)
   PRESET_BOLLINGER_BOUNCE, // Bollinger bounce (band ichiga qaytish)
   PRESET_STOCHASTIC,       // Stochastic (oversold/overbought)
   PRESET_CCI,              // CCI (-100/+100)
   PRESET_TREND_FOLLOWING,  // Trend following (MA yo'nalishi + ADX filtri)
   PRESET_SCALP_RSI,        // Skalping RSI (RSI<25 BUY, >75 SELL)
   PRESET_SCALP_MA,         // Skalping MA (tez kesishuv)
   PRESET_SCALP_STOCH       // Skalping Stochastic (<15 BUY, >85 SELL)
};

//==================================================================
//                    INPUTS (BARCHA SOZLAMALAR)
//==================================================================

//--- 0) STRATEGIYA REJIMI ----------------------------------------
input group "=== 0. STRATEGIYA REJIMI ==="
input ENUM_STRATMODE InpStrategyMode = STRAT_PRESET; // Rejim: PRESET (tayyor) yoki CUSTOM (o'zi quradi)
input ENUM_PRESET    InpPreset       = PRESET_RSI_REVERSAL; // Tayyor strategiya (faqat PRESET rejimida)

input group "=== BOT BOSHQARUVI (Telegram) ==="
input bool   InpUseBotControl = false; // Telegram bot fayl orqali boshqarsin (Common\Files\FUSION_<login>.txt)
input int    InpBotPollSec    = 5;     // Fayl tekshirish oralig'i (soniya)

input group "--- Preset: RSI Reversal ---"
input int    InpPR_RSI_Period = 14;  // RSI davri
input double InpPR_RSI_Buy    = 30;  // BUY darajasi (RSI shundan past)
input double InpPR_RSI_Sell   = 70;  // SELL darajasi (RSI shundan yuqori)

input group "--- Preset: MA Crossover ---"
input int    InpPR_MA_Fast    = 50;  // Tez MA davri
input int    InpPR_MA_Slow    = 200; // Sekin MA davri

input group "--- Preset: Bollinger Bounce ---"
input int    InpPR_BB_Period  = 20;  // Bollinger davri

input group "--- Preset: Stochastic ---"
input int    InpPR_Stoch_K    = 5;   // Stochastic %K davri
input double InpPR_Stoch_Buy  = 20;  // BUY darajasi (shundan past)
input double InpPR_Stoch_Sell = 80;  // SELL darajasi (shundan yuqori)

input group "--- Preset: CCI ---"
input int    InpPR_CCI_Period = 14;  // CCI davri
input double InpPR_CCI_Buy    = -100;// BUY darajasi (shundan past)
input double InpPR_CCI_Sell   = 100; // SELL darajasi (shundan yuqori)

input group "--- Preset: Trend Following ---"
input int    InpPR_Trend_MA   = 100; // Trend MA davri (narx shundan yuqori=trend)
input int    InpPR_Trend_ADXp = 14;  // ADX davri
input double InpPR_Trend_ADXm = 25;  // Minimal ADX (trend kuchi)

//--- 1) UMUMIY / TEXNIK ------------------------------------------
input group "=== 1. UMUMIY / TEXNIK ==="
input long   InpMagic            = 777001;     // Magic Number (robot ID)
input string InpComment          = "FUSION";   // Order Comment
input ulong  InpSlippage         = 30;         // Slippage (deviation, punkt)
input bool   InpEnableAlerts     = false;      // Ekranda Alert berish
input bool   InpPushNotify       = false;      // Telefonga push xabar

//--- 2) VAQT (qachon savdo qilish) -------------------------------
input group "=== 2. VAQT ==="
input int    InpGMTOffset        = 0;          // Broker GMT offset (soat)
input bool   InpUseTimeFilter    = true;       // Vaqt filtrini yoqish
input int    InpStartHour        = 8;          // Savdo boshlanish soati (0-23)
input int    InpStartMinute      = 0;          // Savdo boshlanish daqiqasi
input int    InpEndHour          = 20;         // Savdo tugash soati (0-23)
input int    InpEndMinute        = 0;          // Savdo tugash daqiqasi
input bool   InpTradeMonday      = true;       // Dushanba savdo
input bool   InpTradeTuesday     = true;       // Seshanba savdo
input bool   InpTradeWednesday   = true;       // Chorshanba savdo
input bool   InpTradeThursday    = true;       // Payshanba savdo
input bool   InpTradeFriday      = true;       // Juma savdo
input bool   InpCloseAtEndOfDay  = false;      // Kun oxirida hammasini yopish

//--- 3) JUFTLIK / SPREAD -----------------------------------------
input group "=== 3. JUFTLIK / SPREAD ==="
input bool   InpUseMaxSpread     = true;       // Spread filtrini yoqish
input int    InpMaxSpread        = 30;         // Maksimal ruxsat etilgan spread (punkt)

//--- 4) TIMEFRAME ------------------------------------------------
input group "=== 4. TIMEFRAME ==="
input ENUM_TIMEFRAMES InpEntryTF = PERIOD_CURRENT; // Kirish (signal) timeframe
input bool   InpOnePerBar        = true;       // Har sham (bar)da bitta savdo

//--- 5) LOT / FOIZ (risk hajmi) ----------------------------------
input group "=== 5. LOT / FOIZ ==="
input ENUM_LOTMODE InpLotMode    = LOT_FIXED;  // Lot rejimi
input double InpFixedLot         = 0.10;       // Qat'iy lot
input double InpRiskPercent      = 1.0;        // Risk foizi (balansdan, %)
input double InpMaxLot           = 5.0;        // Maksimal lot chegarasi
input int    InpMaxPositions     = 1;          // Maks. ochiq pozitsiya soni

//--- 6) STOP LOSS / TAKE PROFIT ----------------------------------
input group "=== 6. STOP LOSS / TAKE PROFIT ==="
input ENUM_SLMODE InpSLMode      = SL_FIXED;   // SL rejimi
input int    InpStopLossPoints   = 300;        // Stop Loss (punkt)
input int    InpTakeProfitPoints = 600;        // Take Profit (punkt, 0=o'chiq)
input int    InpATRPeriod        = 14;         // ATR davri (SL_ATR uchun)
input double InpATRMultiplier    = 1.5;        // ATR ko'paytuvchi (SL uchun)
input double InpTP_RR            = 2.0;        // TP risk/reward (ATR rejimida)
input bool   InpUseTrailing      = false;      // Trailing Stop yoqish
input int    InpTrailingStart    = 200;        // Trailing boshlanishi (punkt foyda)
input int    InpTrailingStep     = 150;        // Trailing masofasi (punkt)
input bool   InpUseBreakEven     = false;      // Break-even yoqish
input int    InpBreakEvenTrigger = 200;        // Break-even ishga tushishi (punkt)
input int    InpBreakEvenLock    = 20;         // Break-even qulflanadigan foyda (punkt)

//--- 7) HIMOYA (qachon savdo qilmaslik) --------------------------
input group "=== 7. HIMOYA / LIMITLAR ==="
input bool   InpUseDailyLoss     = false;      // Kunlik zarar limitini yoqish
input double InpDailyLossPercent = 5.0;        // Kunlik maks. zarar (%)
input bool   InpUseDailyProfit   = false;      // Kunlik foyda maqsadini yoqish
input double InpDailyProfitPct   = 5.0;        // Kunlik foyda maqsadi (%)
input bool   InpUseMaxDrawdown   = false;      // Umumiy drawdown limitini yoqish
input double InpMaxDrawdownPct   = 20.0;       // Maksimal drawdown (%)

//--- 8) KIRISH QOIDALARI: BUY (trader quradi) --------------------
input group "=== 8. BUY QOIDALARI ==="
input ENUM_LOGIC InpBuyLogic     = LOGIC_AND;  // BUY shartlar mantig'i
input int    InpBuyVotesNeeded   = 2;          // VOTING uchun kerakli ovoz soni

input group "--- BUY shart 1 ---"
input bool     InpB1_On   = true;        // Shart 1 yoqilgan
input ENUM_IND InpB1_IndA = IND_RSI;     // Indikator A
input int      InpB1_PerA = 14;          // A davri
input ENUM_OP  InpB1_Op   = OP_LESS;     // Operator
input ENUM_CMP InpB1_Cmp  = CMP_VALUE;   // Taqqoslash turi
input double   InpB1_Val  = 30;          // Qiymat
input ENUM_IND InpB1_IndB = IND_NONE;    // Indikator B (CMP_IND bo'lsa)
input int      InpB1_PerB = 14;          // B davri

input group "--- BUY shart 2 ---"
input bool     InpB2_On   = false;       // Shart 2 yoqilgan
input ENUM_IND InpB2_IndA = IND_MA;      // Indikator A
input int      InpB2_PerA = 50;          // A davri
input ENUM_OP  InpB2_Op   = OP_GREATER;  // Operator
input ENUM_CMP InpB2_Cmp  = CMP_IND;     // Taqqoslash turi
input double   InpB2_Val  = 0;           // Qiymat
input ENUM_IND InpB2_IndB = IND_MA;      // Indikator B
input int      InpB2_PerB = 200;         // B davri

input group "--- BUY shart 3 ---"
input bool     InpB3_On   = false;       // Shart 3 yoqilgan
input ENUM_IND InpB3_IndA = IND_PRICE;   // Indikator A
input int      InpB3_PerA = 0;           // A davri
input ENUM_OP  InpB3_Op   = OP_GREATER;  // Operator
input ENUM_CMP InpB3_Cmp  = CMP_IND;     // Taqqoslash turi
input double   InpB3_Val  = 0;           // Qiymat
input ENUM_IND InpB3_IndB = IND_MA;      // Indikator B
input int      InpB3_PerB = 20;          // B davri

input group "--- BUY shart 4 ---"
input bool     InpB4_On   = false;       // Shart 4 yoqilgan
input ENUM_IND InpB4_IndA = IND_NONE;    // Indikator A
input int      InpB4_PerA = 14;          // A davri
input ENUM_OP  InpB4_Op   = OP_GREATER;  // Operator
input ENUM_CMP InpB4_Cmp  = CMP_VALUE;   // Taqqoslash turi
input double   InpB4_Val  = 0;           // Qiymat
input ENUM_IND InpB4_IndB = IND_NONE;    // Indikator B
input int      InpB4_PerB = 14;          // B davri

//--- 9) KIRISH QOIDALARI: SELL (trader quradi) -------------------
input group "=== 9. SELL QOIDALARI ==="
input ENUM_LOGIC InpSellLogic    = LOGIC_AND;  // SELL shartlar mantig'i
input int    InpSellVotesNeeded  = 2;          // VOTING uchun kerakli ovoz soni

input group "--- SELL shart 1 ---"
input bool     InpS1_On   = true;        // Shart 1 yoqilgan
input ENUM_IND InpS1_IndA = IND_RSI;     // Indikator A
input int      InpS1_PerA = 14;          // A davri
input ENUM_OP  InpS1_Op   = OP_GREATER;  // Operator
input ENUM_CMP InpS1_Cmp  = CMP_VALUE;   // Taqqoslash turi
input double   InpS1_Val  = 70;          // Qiymat
input ENUM_IND InpS1_IndB = IND_NONE;    // Indikator B
input int      InpS1_PerB = 14;          // B davri

input group "--- SELL shart 2 ---"
input bool     InpS2_On   = false;       // Shart 2 yoqilgan
input ENUM_IND InpS2_IndA = IND_MA;      // Indikator A
input int      InpS2_PerA = 50;          // A davri
input ENUM_OP  InpS2_Op   = OP_LESS;     // Operator
input ENUM_CMP InpS2_Cmp  = CMP_IND;     // Taqqoslash turi
input double   InpS2_Val  = 0;           // Qiymat
input ENUM_IND InpS2_IndB = IND_MA;      // Indikator B
input int      InpS2_PerB = 200;         // B davri

input group "--- SELL shart 3 ---"
input bool     InpS3_On   = false;       // Shart 3 yoqilgan
input ENUM_IND InpS3_IndA = IND_PRICE;   // Indikator A
input int      InpS3_PerA = 0;           // A davri
input ENUM_OP  InpS3_Op   = OP_LESS;     // Operator
input ENUM_CMP InpS3_Cmp  = CMP_IND;     // Taqqoslash turi
input double   InpS3_Val  = 0;           // Qiymat
input ENUM_IND InpS3_IndB = IND_MA;      // Indikator B
input int      InpS3_PerB = 20;          // B davri

input group "--- SELL shart 4 ---"
input bool     InpS4_On   = false;       // Shart 4 yoqilgan
input ENUM_IND InpS4_IndA = IND_NONE;    // Indikator A
input int      InpS4_PerA = 14;          // A davri
input ENUM_OP  InpS4_Op   = OP_LESS;     // Operator
input ENUM_CMP InpS4_Cmp  = CMP_VALUE;   // Taqqoslash turi
input double   InpS4_Val  = 0;           // Qiymat
input ENUM_IND InpS4_IndB = IND_NONE;    // Indikator B
input int      InpS4_PerB = 14;          // B davri

//--- 10) CHIQISH QOIDALARI ---------------------------------------
input group "=== 10. CHIQISH ==="
input ENUM_EXITMODE InpExitMode = EXIT_SLTP_ONLY; // Chiqish rejimi

//==================================================================
//                       GLOBAL OBYEKTLAR
//==================================================================
CTrade        trade;
CPositionInfo posInfo;
CSymbolInfo   symInfo;

ENUM_TIMEFRAMES g_tf;          // ishchi timeframe
datetime        g_lastBarTime; // oxirgi qayta ishlangan bar vaqti
double          g_dayStartEquity; // kun boshidagi equity
int             g_dayStartDOY;    // kun raqami (yil ichida)
bool            g_tradingHalted;  // limit oshganda to'xtatish
string          g_symbol;         // savdo juftligi (grafik yoki bot tanlaydi)

//--- Bot boshqaruvi (fayl bridge) override qiymatlari ---
bool            g_botEnabled = true;   // bot ruxsat berganmi (savdo ochish)
bool            g_engineAllowsEA = true; // bridge engine=PYTHON bo'lsa false
double          g_ovLot;               // lot (bot yoki input)
int             g_ovSL;                // stop loss punkt
int             g_ovTP;                // take profit punkt
double          g_ovRisk;              // risk foizi
ENUM_PRESET     g_ovPreset;            // faol preset
ENUM_TIMEFRAMES g_ovTF;                // faol timeframe

//--- Indikator handle cache (samaradorlik uchun) ---
struct IndHandle
{
   int             itype;   // normalizatsiyalangan indikator turi
   int             period;  // davr
   long            tf;      // timeframe
   int             handle;  // indikator handle
};
IndHandle g_hcache[];

//==================================================================
//                    SHART STRUKTURASI
//==================================================================
struct Condition
{
   bool      on;
   ENUM_IND  indA;
   int       perA;
   ENUM_OP   op;
   ENUM_CMP  cmp;
   double    val;
   ENUM_IND  indB;
   int       perB;
};

Condition g_buy[4];
Condition g_sell[4];

// Faol logika (CUSTOM'da input'dan, PRESET'da strategiyadan o'rnatiladi)
ENUM_LOGIC g_buyLogic;
ENUM_LOGIC g_sellLogic;
int        g_buyVotes;
int        g_sellVotes;

//==================================================================
//                       OnInit
//==================================================================
int OnInit()
{
   g_symbol = _Symbol; // standart: grafik juftligi (bot boshqarsa keyin o'zgaradi)
   g_tf = (InpEntryTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpEntryTF;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(g_symbol);

   if(!symInfo.Name(g_symbol))
   {
      Print("Symbol info xatosi");
      return(INIT_FAILED);
   }

   // Shartlarni bo'shatish
   ClearConditions();

   if(InpStrategyMode == STRAT_CUSTOM)
   {
      // CUSTOM: trader o'zi qurgan 4+4 shartlarni yuklash
      g_buyLogic  = InpBuyLogic;
      g_sellLogic = InpSellLogic;
      g_buyVotes  = InpBuyVotesNeeded;
      g_sellVotes = InpSellVotesNeeded;

      // BUY shartlarni yuklash
      LoadCond(g_buy[0], InpB1_On, InpB1_IndA, InpB1_PerA, InpB1_Op, InpB1_Cmp, InpB1_Val, InpB1_IndB, InpB1_PerB);
      LoadCond(g_buy[1], InpB2_On, InpB2_IndA, InpB2_PerA, InpB2_Op, InpB2_Cmp, InpB2_Val, InpB2_IndB, InpB2_PerB);
      LoadCond(g_buy[2], InpB3_On, InpB3_IndA, InpB3_PerA, InpB3_Op, InpB3_Cmp, InpB3_Val, InpB3_IndB, InpB3_PerB);
      LoadCond(g_buy[3], InpB4_On, InpB4_IndA, InpB4_PerA, InpB4_Op, InpB4_Cmp, InpB4_Val, InpB4_IndB, InpB4_PerB);

      // SELL shartlarni yuklash
      LoadCond(g_sell[0], InpS1_On, InpS1_IndA, InpS1_PerA, InpS1_Op, InpS1_Cmp, InpS1_Val, InpS1_IndB, InpS1_PerB);
      LoadCond(g_sell[1], InpS2_On, InpS2_IndA, InpS2_PerA, InpS2_Op, InpS2_Cmp, InpS2_Val, InpS2_IndB, InpS2_PerB);
      LoadCond(g_sell[2], InpS3_On, InpS3_IndA, InpS3_PerA, InpS3_Op, InpS3_Cmp, InpS3_Val, InpS3_IndB, InpS3_PerB);
      LoadCond(g_sell[3], InpS4_On, InpS4_IndA, InpS4_PerA, InpS4_Op, InpS4_Cmp, InpS4_Val, InpS4_IndB, InpS4_PerB);

      Print("FUSION: CUSTOM rejim - trader qoidalari yuklandi");
   }
   else
   {
      // PRESET: tanlangan tayyor strategiyani qurish
      BuildPreset(InpPreset);
      Print("FUSION: PRESET rejim - strategiya: ", EnumToString(InpPreset));
   }

   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayStartDOY    = CurrentDayOfYear();
   g_tradingHalted  = false;
   g_lastBarTime    = 0;

   // Bot override qiymatlarini input'lardan boshlang'ich holatga keltirish
   g_ovLot    = InpFixedLot;
   g_ovSL     = InpStopLossPoints;
   g_ovTP     = InpTakeProfitPoints;
   g_ovRisk   = InpRiskPercent;
   g_ovPreset = InpPreset;
   g_ovTF     = g_tf;
   g_botEnabled = true;

   // Engine guard har doim kuzatiladi. InpUseBotControl=false bo'lsa ham
   // engine=PYTHON buyrug'i EA va Python parallel savdosini bloklaydi.
   ReadBridgeFile();
   int poll = (InpBotPollSec < 1) ? 1 : InpBotPollSec;
   EventSetTimer(poll);
   if(InpUseBotControl)
      Print("FUSION: Bot boshqaruvi YOQILGAN (fayl bridge)");
   else
      Print("FUSION: Standalone EA; engine guard kuzatilmoqda");

   Print("FUSION EA ishga tushdi. Symbol=", g_symbol, " TF=", EnumToString(g_tf));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ClearHandleCache();
}

//==================================================================
//        BOT BOSHQARUVI: fayl bridge (Common\Files)
//==================================================================
void OnTimer()
{
   ReadBridgeFile();
}

// Strategiya nomini (bot yuboradigan) ENUM_PRESET ga aylantirish
bool StrategyToPreset(string s, ENUM_PRESET &out)
{
   if(s=="RSI_REVERSAL")     { out=PRESET_RSI_REVERSAL;     return(true); }
   if(s=="MA_CROSSOVER")     { out=PRESET_MA_CROSSOVER;     return(true); }
   if(s=="MACD_CROSS")       { out=PRESET_MACD_CROSS;       return(true); }
   if(s=="BOLLINGER_BOUNCE") { out=PRESET_BOLLINGER_BOUNCE; return(true); }
   if(s=="STOCHASTIC")       { out=PRESET_STOCHASTIC;       return(true); }
   if(s=="CCI")              { out=PRESET_CCI;              return(true); }
   if(s=="TREND_FOLLOWING")  { out=PRESET_TREND_FOLLOWING;  return(true); }
   if(s=="SCALP_RSI")        { out=PRESET_SCALP_RSI;        return(true); }
   if(s=="SCALP_MA")         { out=PRESET_SCALP_MA;         return(true); }
   if(s=="SCALP_STOCH")      { out=PRESET_SCALP_STOCH;      return(true); }
   return(false);
}

// Timeframe matnini (M1, M5, H1...) ENUM_TIMEFRAMES ga aylantirish
bool TFStringToEnum(string s, ENUM_TIMEFRAMES &out)
{
   if(s=="M1")  { out=PERIOD_M1;  return(true); }
   if(s=="M5")  { out=PERIOD_M5;  return(true); }
   if(s=="M15") { out=PERIOD_M15; return(true); }
   if(s=="M30") { out=PERIOD_M30; return(true); }
   if(s=="H1")  { out=PERIOD_H1;  return(true); }
   if(s=="H4")  { out=PERIOD_H4;  return(true); }
   if(s=="D1")  { out=PERIOD_D1;  return(true); }
   if(s=="W1")  { out=PERIOD_W1;  return(true); }
   return(false);
}

// Bot buyruq faylini o'qish: Common\Files\FUSION_<login>.txt
void ReadBridgeFile()
{
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   string fname = StringFormat("FUSION_%I64d.txt", login);

   int h = FileOpen(fname, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h==INVALID_HANDLE)
      return; // fayl hali yo'q — input sozlamalari bilan ishlaydi

   string engine   = "";
   string strategy = "";
   string tfStr    = "";
   string symStr   = "";
   bool   enabled  = g_botEnabled;
   double lot=g_ovLot; int sl=g_ovSL; int tp=g_ovTP; double risk=g_ovRisk;

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      StringTrimLeft(line);
      StringTrimRight(line);
      int pos = StringFind(line, "=");
      if(pos<=0) continue;
      string key = StringSubstr(line, 0, pos);
      string val = StringSubstr(line, pos+1);

      if(key=="engine")             engine = val;
      else if(key=="enabled")       enabled = (StringToInteger(val)==1);
      else if(key=="strategy")  strategy = val;
      else if(key=="symbol")    symStr = val;
      else if(key=="timeframe") tfStr = val;
      else if(key=="lot")       lot = StringToDouble(val);
      else if(key=="sl")        sl = (int)StringToInteger(val);
      else if(key=="tp")        tp = (int)StringToInteger(val);
      else if(key=="risk")      risk = StringToDouble(val);
   }
   FileClose(h);

   // Engine guard InpUseBotControl'dan mustaqil. Python dvigateli faol
   // bo'lsa EA hech qachon yangi savdo ochmaydi.
   if(engine=="PYTHON")
   {
      g_engineAllowsEA = false;
      g_botEnabled = false;
      return;
   }
   g_engineAllowsEA = true;

   // Standalone EA rejimida faqat engine guard qo'llanadi; botning qolgan
   // strategy/symbol/lot override qiymatlari Inputs'ni o'zgartirmaydi.
   if(!InpUseBotControl)
      return;

   // Qiymatlarni qo'llash
   g_botEnabled = enabled;
   if(lot>0)  g_ovLot  = lot;
   if(sl>=0)  g_ovSL   = sl;
   if(tp>=0)  g_ovTP   = tp;
   if(risk>0) g_ovRisk = risk;

   // Symbol (juftlik) o'zgargan bo'lsa
   if(symStr!="" && symStr!=g_symbol)
   {
      if(SymbolSelect(symStr, true) && symInfo.Name(symStr))
      {
         g_symbol = symStr;
         g_lastBarTime = 0;
         ClearHandleCache(); // eski juftlik handle'lari kerak emas
         Print("FUSION (bot): juftlik o'zgardi -> ", symStr);
      }
      else
      {
         Print("FUSION (bot): juftlik topilmadi -> ", symStr, " (broker nomini tekshiring)");
      }
   }

   // Strategiya o'zgargan bo'lsa — qayta qurish
   ENUM_PRESET p;
   if(strategy!="" && StrategyToPreset(strategy, p))
   {
      if(p!=g_ovPreset)
      {
         g_ovPreset = p;
         ClearConditions();
         BuildPreset(g_ovPreset);
         Print("FUSION (bot): strategiya o'zgardi -> ", strategy);
      }
   }

   // Timeframe o'zgargan bo'lsa
   ENUM_TIMEFRAMES tf;
   if(tfStr!="" && TFStringToEnum(tfStr, tf))
   {
      if(tf!=g_tf)
      {
         g_tf = tf;
         g_ovTF = tf;
         g_lastBarTime = 0;
         ClearHandleCache(); // eski timeframe handle'lari kerak emas
         Print("FUSION (bot): timeframe o'zgardi -> ", tfStr);
      }
   }
}

//==================================================================
//                  Shartni strukturaga yuklash
//==================================================================
void LoadCond(Condition &c, bool on, ENUM_IND indA, int perA, ENUM_OP op,
              ENUM_CMP cmp, double val, ENUM_IND indB, int perB)
{
   c.on=on; c.indA=indA; c.perA=perA; c.op=op; c.cmp=cmp; c.val=val; c.indB=indB; c.perB=perB;
}

//==================================================================
//             Barcha shartlarni bo'shatish (o'chirish)
//==================================================================
void ClearConditions()
{
   for(int i=0; i<4; i++)
   {
      LoadCond(g_buy[i],  false, IND_NONE, 14, OP_GREATER, CMP_VALUE, 0, IND_NONE, 14);
      LoadCond(g_sell[i], false, IND_NONE, 14, OP_GREATER, CMP_VALUE, 0, IND_NONE, 14);
   }
}

//==================================================================
//        TAYYOR STRATEGIYANI QURISH (PRESET rejimi)
//==================================================================
void BuildPreset(ENUM_PRESET preset)
{
   // Standart: bitta shartli strategiyalar uchun AND yetarli
   g_buyLogic  = LOGIC_AND;
   g_sellLogic = LOGIC_AND;
   g_buyVotes  = 1;
   g_sellVotes = 1;

   switch(preset)
   {
      //--- 1) RSI Reversal: RSI<Buy -> BUY, RSI>Sell -> SELL ---
      case PRESET_RSI_REVERSAL:
         LoadCond(g_buy[0],  true, IND_RSI, InpPR_RSI_Period, OP_LESS,    CMP_VALUE, InpPR_RSI_Buy,  IND_NONE, 0);
         LoadCond(g_sell[0], true, IND_RSI, InpPR_RSI_Period, OP_GREATER, CMP_VALUE, InpPR_RSI_Sell, IND_NONE, 0);
         break;

      //--- 2) MA Crossover: tez MA sekin MA ni kesib o'tsa ---
      case PRESET_MA_CROSSOVER:
         LoadCond(g_buy[0],  true, IND_MA, InpPR_MA_Fast, OP_CROSS_ABOVE, CMP_IND, 0, IND_MA, InpPR_MA_Slow);
         LoadCond(g_sell[0], true, IND_MA, InpPR_MA_Fast, OP_CROSS_BELOW, CMP_IND, 0, IND_MA, InpPR_MA_Slow);
         break;

      //--- 3) MACD Crossover: main signal'ni kesib o'tsa ---
      case PRESET_MACD_CROSS:
         LoadCond(g_buy[0],  true, IND_MACD_MAIN, 12, OP_CROSS_ABOVE, CMP_IND, 0, IND_MACD_SIGNAL, 9);
         LoadCond(g_sell[0], true, IND_MACD_MAIN, 12, OP_CROSS_BELOW, CMP_IND, 0, IND_MACD_SIGNAL, 9);
         break;

      //--- 4) Bollinger Bounce: band tashqarisidan ichkariga qaytsa ---
      case PRESET_BOLLINGER_BOUNCE:
         LoadCond(g_buy[0],  true, IND_PRICE, 0, OP_CROSS_ABOVE, CMP_IND, 0, IND_BB_LOWER, InpPR_BB_Period);
         LoadCond(g_sell[0], true, IND_PRICE, 0, OP_CROSS_BELOW, CMP_IND, 0, IND_BB_UPPER, InpPR_BB_Period);
         break;

      //--- 5) Stochastic: Stoch<Buy -> BUY, Stoch>Sell -> SELL ---
      case PRESET_STOCHASTIC:
         LoadCond(g_buy[0],  true, IND_STOCH, InpPR_Stoch_K, OP_LESS,    CMP_VALUE, InpPR_Stoch_Buy,  IND_NONE, 0);
         LoadCond(g_sell[0], true, IND_STOCH, InpPR_Stoch_K, OP_GREATER, CMP_VALUE, InpPR_Stoch_Sell, IND_NONE, 0);
         break;

      //--- 6) CCI: CCI<Buy -> BUY, CCI>Sell -> SELL ---
      case PRESET_CCI:
         LoadCond(g_buy[0],  true, IND_CCI, InpPR_CCI_Period, OP_LESS,    CMP_VALUE, InpPR_CCI_Buy,  IND_NONE, 0);
         LoadCond(g_sell[0], true, IND_CCI, InpPR_CCI_Period, OP_GREATER, CMP_VALUE, InpPR_CCI_Sell, IND_NONE, 0);
         break;

      //--- 7) Trend Following: narx MA dan yuqori + ADX kuchli ---
      case PRESET_TREND_FOLLOWING:
         // BUY: Price > MA(trend) AND ADX > min
         LoadCond(g_buy[0],  true, IND_PRICE, 0,              OP_GREATER, CMP_IND,   0,             IND_MA, InpPR_Trend_MA);
         LoadCond(g_buy[1],  true, IND_ADX,   InpPR_Trend_ADXp, OP_GREATER, CMP_VALUE, InpPR_Trend_ADXm, IND_NONE, 0);
         // SELL: Price < MA(trend) AND ADX > min
         LoadCond(g_sell[0], true, IND_PRICE, 0,              OP_LESS,    CMP_IND,   0,             IND_MA, InpPR_Trend_MA);
         LoadCond(g_sell[1], true, IND_ADX,   InpPR_Trend_ADXp, OP_GREATER, CMP_VALUE, InpPR_Trend_ADXm, IND_NONE, 0);
         g_buyLogic  = LOGIC_AND; // ikkala shart ham bajarilsin
         g_sellLogic = LOGIC_AND;
         break;

      //--- 8) Skalping RSI: RSI<25 BUY, RSI>75 SELL (qisqa davr) ---
      case PRESET_SCALP_RSI:
         LoadCond(g_buy[0],  true, IND_RSI, 7, OP_LESS,    CMP_VALUE, 25, IND_NONE, 0);
         LoadCond(g_sell[0], true, IND_RSI, 7, OP_GREATER, CMP_VALUE, 75, IND_NONE, 0);
         break;

      //--- 9) Skalping MA: tez MA(5) sekin MA(20) ni kesib o'tsa ---
      case PRESET_SCALP_MA:
         LoadCond(g_buy[0],  true, IND_MA, 5, OP_CROSS_ABOVE, CMP_IND, 0, IND_MA, 20);
         LoadCond(g_sell[0], true, IND_MA, 5, OP_CROSS_BELOW, CMP_IND, 0, IND_MA, 20);
         break;

      //--- 10) Skalping Stochastic: Stoch<15 BUY, Stoch>85 SELL ---
      case PRESET_SCALP_STOCH:
         LoadCond(g_buy[0],  true, IND_STOCH, 5, OP_LESS,    CMP_VALUE, 15, IND_NONE, 0);
         LoadCond(g_sell[0], true, IND_STOCH, 5, OP_GREATER, CMP_VALUE, 85, IND_NONE, 0);
         break;
   }
}

//==================================================================
//                          OnTick
//==================================================================
void OnTick()
{
   // Kun almashganini tekshirish (kunlik limitlarni reset qilish)
   int doy = CurrentDayOfYear();
   if(doy != g_dayStartDOY)
   {
      g_dayStartDOY    = doy;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_tradingHalted  = false;
   }

   // Engine guard eng birinchi tekshiriladi. engine=PYTHON bo'lsa EA
   // umuman hech narsa qilmaydi (savdo ham, pozitsiya boshqaruvi ham) —
   // shu tariqa Python bilan bir xil magic pozitsiyalarda SL/TP ustida
   // kurash bo'lmaydi.
   if(!g_engineAllowsEA)
      return;

   // Ochiq pozitsiyalarni boshqarish (har tickda)
   ManageOpenPositions();

   // Bot boshqaruvi: bot to'xtatgan bo'lsa yangi savdo ochilmaydi
   if(InpUseBotControl && !g_botEnabled)
      return;

   // Faqat yangi bar ochilganda signal tekshiriladi (agar OnePerBar=true)
   datetime curBar = iTime(g_symbol, g_tf, 0);
   bool newBar = (curBar != g_lastBarTime);
   if(InpOnePerBar && !newBar)
      return;
   if(newBar)
      g_lastBarTime = curBar;

   // Himoya limitlari
   if(!RiskChecksPass())
      return;

   // Vaqt filtri
   if(!TimeAllowed())
   {
      if(InpCloseAtEndOfDay) CloseAllPositions();
      return;
   }

   // Spread filtri
   if(InpUseMaxSpread && CurrentSpreadPoints() > InpMaxSpread)
      return;

   // Signal hisoblash (faqat yopilgan barlar bo'yicha)
   bool buySignal  = EvaluateSide(g_buy,  g_buyLogic,  g_buyVotes);
   bool sellSignal = EvaluateSide(g_sell, g_sellLogic, g_sellVotes);

   // Bir vaqtda ikkalasi ham signal bersa — pozitsiyani ham yopmaymiz,
   // yangi savdo ham ochmaymiz (ziddiyatli signal).
   if(buySignal && sellSignal)
      return;

   // Qarama-qarshi signalda yopish maksimal pozitsiya filtridan oldin
   // bajarilishi kerak; aks holda MaxPositions=1 da bu rejim ishlamaydi.
   if(InpExitMode == EXIT_OPPOSITE_SIGNAL || InpExitMode == EXIT_BOTH)
   {
      if(buySignal)  ClosePositionsByType(POSITION_TYPE_SELL);
      if(sellSignal) ClosePositionsByType(POSITION_TYPE_BUY);
   }

   // Yopishlardan keyin maksimal pozitsiya sonini qayta tekshiramiz.
   if(CountPositions() >= InpMaxPositions)
      return;

   if(buySignal)
      OpenTrade(ORDER_TYPE_BUY);
   else if(sellSignal)
      OpenTrade(ORDER_TYPE_SELL);
}

//==================================================================
//        BIR TOMON (BUY yoki SELL) shartlarini baholash
//==================================================================
bool EvaluateSide(Condition &arr[], ENUM_LOGIC logic, int votesNeeded)
{
   int enabled=0, passed=0;
   for(int i=0; i<ArraySize(arr); i++)
   {
      if(!arr[i].on || arr[i].indA==IND_NONE) continue;
      enabled++;
      if(EvaluateCondition(arr[i])) passed++;
   }

   if(enabled==0) return(false); // hech qanday shart yo'q

   if(logic==LOGIC_AND)    return(passed==enabled);
   if(logic==LOGIC_OR)     return(passed>=1);
   if(logic==LOGIC_VOTING) return(passed>=votesNeeded);
   return(false);
}

//==================================================================
//                 BITTA SHARTNI baholash
//==================================================================
bool EvaluateCondition(Condition &c)
{
   // Signal faqat yopilgan barlarda hisoblanadi:
   // current = oxirgi yopilgan bar (shift 1), previous = undan oldingi (shift 2).
   double aCurrent, aPrevious;
   double bCurrent, bPrevious;

   if(!GetIndValue(c.indA, c.perA, 1, aCurrent))  return(false);
   if(!GetIndValue(c.indA, c.perA, 2, aPrevious)) return(false);

   if(c.cmp==CMP_VALUE)
   {
      bCurrent  = c.val;
      bPrevious = c.val;
   }
   else // CMP_IND
   {
      if(c.indB==IND_NONE) return(false);
      if(!GetIndValue(c.indB, c.perB, 1, bCurrent))  return(false);
      if(!GetIndValue(c.indB, c.perB, 2, bPrevious)) return(false);
   }

   switch(c.op)
   {
      case OP_GREATER:     return(aCurrent > bCurrent);
      case OP_LESS:        return(aCurrent < bCurrent);
      case OP_CROSS_ABOVE: return(aPrevious <= bPrevious && aCurrent > bCurrent);
      case OP_CROSS_BELOW: return(aPrevious >= bPrevious && aCurrent < bCurrent);
   }
   return(false);
}

//==================================================================
//        INDIKATOR QIYMATINI olish (shift bo'yicha)
//==================================================================
bool GetIndValue(ENUM_IND ind, int period, int shift, double &out)
{
   out=0;
   if(period<1) period=1;
   double buf[];

   // Narx — handle kerak emas
   if(ind==IND_PRICE)
   {
      out = iClose(g_symbol, g_tf, shift);
      return(out>0);
   }

   int handle = GetHandle(ind, period);
   if(handle==INVALID_HANDLE) return(false);

   int bufIndex = 0;
   if(ind==IND_MACD_SIGNAL) bufIndex = 1; // signal liniya
   if(ind==IND_BB_UPPER)    bufIndex = 1; // upper band
   if(ind==IND_BB_LOWER)    bufIndex = 2; // lower band

   // Handle cache qilinadi — bu yerda RELEASE qilinmaydi
   if(CopyBuffer(handle, bufIndex, shift, 1, buf) < 1)
      return(false);
   out = buf[0];
   return(true);
}

//==================================================================
//   INDIKATOR HANDLE olish (cache bilan) — qayta yaratmaydi
//==================================================================
int GetHandle(ENUM_IND ind, int period)
{
   if(period<1) period=1;

   // Normalizatsiya: MACD ikkala liniyasi va BB ikkala chizig'i bitta handle
   int key = (int)ind;
   if(ind==IND_MACD_SIGNAL) key = (int)IND_MACD_MAIN;
   if(ind==IND_BB_LOWER)    key = (int)IND_BB_UPPER;

   // Cache da qidirish
   for(int i=0; i<ArraySize(g_hcache); i++)
      if(g_hcache[i].itype==key && g_hcache[i].period==period && g_hcache[i].tf==(long)g_tf)
         return(g_hcache[i].handle);

   // Topilmadi — yangi yaratish
   int handle = INVALID_HANDLE;
   ENUM_IND base = (ENUM_IND)key;
   switch(base)
   {
      case IND_MA:        handle = iMA(g_symbol, g_tf, period, 0, MODE_EMA, PRICE_CLOSE);            break;
      case IND_RSI:       handle = iRSI(g_symbol, g_tf, period, PRICE_CLOSE);                        break;
      case IND_MACD_MAIN: handle = iMACD(g_symbol, g_tf, 12, 26, 9, PRICE_CLOSE);                    break;
      case IND_STOCH:     handle = iStochastic(g_symbol, g_tf, period, 3, 3, MODE_SMA, STO_LOWHIGH); break;
      case IND_CCI:       handle = iCCI(g_symbol, g_tf, period, PRICE_TYPICAL);                      break;
      case IND_ADX:       handle = iADX(g_symbol, g_tf, period);                                     break;
      case IND_ATR:       handle = iATR(g_symbol, g_tf, period);                                     break;
      case IND_BB_UPPER:  handle = iBands(g_symbol, g_tf, period, 0, 2.0, PRICE_CLOSE);              break;
      default:            return(INVALID_HANDLE);
   }
   if(handle==INVALID_HANDLE) return(INVALID_HANDLE);

   int n = ArraySize(g_hcache);
   ArrayResize(g_hcache, n+1);
   g_hcache[n].itype  = key;
   g_hcache[n].period = period;
   g_hcache[n].tf     = (long)g_tf;
   g_hcache[n].handle = handle;
   return(handle);
}

//==================================================================
//   Handle cache ni tozalash (timeframe o'zgarganda / deinit)
//==================================================================
void ClearHandleCache()
{
   for(int i=0; i<ArraySize(g_hcache); i++)
      if(g_hcache[i].handle!=INVALID_HANDLE)
         IndicatorRelease(g_hcache[i].handle);
   ArrayResize(g_hcache, 0);
}

//==================================================================
//                        SAVDO OCHISH
//==================================================================
void OpenTrade(ENUM_ORDER_TYPE type)
{
   symInfo.RefreshRates();
   double price = (type==ORDER_TYPE_BUY) ? symInfo.Ask() : symInfo.Bid();
   double point = symInfo.Point();
   int    digits= (int)symInfo.Digits();

   // SL/TP masofalarini hisoblash (punktda)
   double slPts = 0, tpPts = 0;
   if(InpSLMode==SL_FIXED)
   {
      slPts = g_ovSL;
      tpPts = g_ovTP;
   }
   else if(InpSLMode==SL_ATR)
   {
      double atr;
      if(GetIndValue(IND_ATR, InpATRPeriod, 0, atr) && atr>0)
      {
         slPts = (atr * InpATRMultiplier) / point;
         tpPts = slPts * InpTP_RR;
      }
      else
      {
         slPts = g_ovSL; // zaxira
         tpPts = g_ovTP;
      }
   }
   // SL_OFF: slPts=0 qoladi

   double sl=0, tp=0;
   if(type==ORDER_TYPE_BUY)
   {
      if(slPts>0) sl = NormalizeDouble(price - slPts*point, digits);
      if(tpPts>0) tp = NormalizeDouble(price + tpPts*point, digits);
   }
   else
   {
      if(slPts>0) sl = NormalizeDouble(price + slPts*point, digits);
      if(tpPts>0) tp = NormalizeDouble(price - tpPts*point, digits);
   }

   double lot = CalcLot(slPts);
   if(lot<=0) return;

   bool ok=false;
   if(type==ORDER_TYPE_BUY)
      ok = trade.Buy(lot, g_symbol, 0.0, sl, tp, InpComment);
   else
      ok = trade.Sell(lot, g_symbol, 0.0, sl, tp, InpComment);

   if(ok)
      Notify(StringFormat("FUSION: %s ochildi. Lot=%.2f SL=%.5f TP=%.5f",
             (type==ORDER_TYPE_BUY?"BUY":"SELL"), lot, sl, tp));
   else
      Print("FUSION: Savdo ochish xatosi #", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
}

//==================================================================
//                       LOT HISOBLASH
//==================================================================
double CalcLot(double slPts)
{
   double lot = g_ovLot;

   if(InpLotMode==LOT_RISK_PERCENT && slPts>0)
   {
      double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * g_ovRisk / 100.0;
      double tickVal   = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
      double point     = symInfo.Point();
      if(tickSize>0 && tickVal>0)
      {
         double valuePerPointPerLot = tickVal * (point / tickSize);
         double slMoneyPerLot = slPts * valuePerPointPerLot;
         if(slMoneyPerLot>0)
            lot = riskMoney / slMoneyPerLot;
      }
   }

   // Lotni normalizatsiya qilish
   double minLot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX);
   double stepLot= SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);

   if(lot > InpMaxLot) lot = InpMaxLot;
   if(stepLot>0) lot = MathFloor(lot/stepLot)*stepLot;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   return(NormalizeDouble(lot, 2));
}

//==================================================================
//             OCHIQ POZITSIYALARNI BOSHQARISH
//==================================================================
void ManageOpenPositions()
{
   double point = symInfo.Point();
   int    digits= (int)symInfo.Digits();

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!posInfo.SelectByTicket(ticket)) continue;
      if(posInfo.Symbol()!=g_symbol) continue;
      if(posInfo.Magic()!=InpMagic)  continue;

      symInfo.RefreshRates();
      ENUM_POSITION_TYPE ptype = posInfo.PositionType();
      double openPrice = posInfo.PriceOpen();
      double curSL     = posInfo.StopLoss();
      double curTP     = posInfo.TakeProfit();
      double curPrice  = (ptype==POSITION_TYPE_BUY) ? symInfo.Bid() : symInfo.Ask();

      double profitPts = (ptype==POSITION_TYPE_BUY)
                         ? (curPrice-openPrice)/point
                         : (openPrice-curPrice)/point;

      double newSL = curSL;

      // Break-even
      if(InpUseBreakEven && profitPts >= InpBreakEvenTrigger)
      {
         double bePrice = (ptype==POSITION_TYPE_BUY)
                          ? NormalizeDouble(openPrice + InpBreakEvenLock*point, digits)
                          : NormalizeDouble(openPrice - InpBreakEvenLock*point, digits);
         if(ptype==POSITION_TYPE_BUY  && (curSL<bePrice || curSL==0)) newSL=bePrice;
         if(ptype==POSITION_TYPE_SELL && (curSL>bePrice || curSL==0)) newSL=bePrice;
      }

      // Trailing Stop
      if(InpUseTrailing && profitPts >= InpTrailingStart)
      {
         double trailPrice = (ptype==POSITION_TYPE_BUY)
                             ? NormalizeDouble(curPrice - InpTrailingStep*point, digits)
                             : NormalizeDouble(curPrice + InpTrailingStep*point, digits);
         if(ptype==POSITION_TYPE_BUY  && trailPrice>newSL) newSL=trailPrice;
         if(ptype==POSITION_TYPE_SELL && (trailPrice<newSL || newSL==0)) newSL=trailPrice;
      }

      if(newSL!=curSL && newSL!=0)
         trade.PositionModify(ticket, newSL, curTP);
   }
}

//==================================================================
//                  YORDAMCHI FUNKSIYALAR
//==================================================================

// Kunlik / drawdown limitlarini tekshirish
bool RiskChecksPass()
{
   if(g_tradingHalted) return(false);

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Kunlik zarar
   if(InpUseDailyLoss && g_dayStartEquity>0)
   {
      double lossPct = (g_dayStartEquity - equity) / g_dayStartEquity * 100.0;
      if(lossPct >= InpDailyLossPercent)
      {
         HaltTrading("Kunlik zarar limiti oshdi");
         return(false);
      }
   }

   // Kunlik foyda maqsadi
   if(InpUseDailyProfit && g_dayStartEquity>0)
   {
      double profPct = (equity - g_dayStartEquity) / g_dayStartEquity * 100.0;
      if(profPct >= InpDailyProfitPct)
      {
         HaltTrading("Kunlik foyda maqsadiga yetildi");
         return(false);
      }
   }

   // Umumiy drawdown
   if(InpUseMaxDrawdown && balance>0)
   {
      double ddPct = (balance - equity) / balance * 100.0;
      if(ddPct >= InpMaxDrawdownPct)
      {
         HaltTrading("Maksimal drawdown limiti oshdi");
         return(false);
      }
   }
   return(true);
}

void HaltTrading(string reason)
{
   if(!g_tradingHalted)
   {
      g_tradingHalted = true;
      Notify("FUSION TO'XTATILDI: " + reason);
      if(InpCloseAtEndOfDay) CloseAllPositions();
   }
}

// Vaqt (soat + kun) ruxsat etilganmi?
bool TimeAllowed()
{
   if(!InpUseTimeFilter) return(true);

   MqlDateTime dt;
   datetime t = TimeCurrent() + InpGMTOffset*3600;
   TimeToStruct(t, dt);

   // Kun tekshiruvi
   switch(dt.day_of_week)
   {
      case 1: if(!InpTradeMonday)    return(false); break;
      case 2: if(!InpTradeTuesday)   return(false); break;
      case 3: if(!InpTradeWednesday) return(false); break;
      case 4: if(!InpTradeThursday)  return(false); break;
      case 5: if(!InpTradeFriday)    return(false); break;
      case 0:
      case 6: return(false); // shanba/yakshanba
   }

   // Soat oralig'i
   int nowMin   = dt.hour*60 + dt.min;
   int startMin = InpStartHour*60 + InpStartMinute;
   int endMin   = InpEndHour*60 + InpEndMinute;

   if(startMin <= endMin)
      return(nowMin>=startMin && nowMin<endMin);
   else // tunni qamrab oluvchi oraliq (masalan 22:00 - 06:00)
      return(nowMin>=startMin || nowMin<endMin);
}

int CurrentSpreadPoints()
{
   return((int)SymbolInfoInteger(g_symbol, SYMBOL_SPREAD));
}

int CountPositions()
{
   int cnt=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!posInfo.SelectByTicket(ticket)) continue;
      if(posInfo.Symbol()==g_symbol && posInfo.Magic()==InpMagic) cnt++;
   }
   return(cnt);
}

void ClosePositionsByType(ENUM_POSITION_TYPE ptype)
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!posInfo.SelectByTicket(ticket)) continue;
      if(posInfo.Symbol()==g_symbol && posInfo.Magic()==InpMagic && posInfo.PositionType()==ptype)
         trade.PositionClose(ticket);
   }
}

void CloseAllPositions()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!posInfo.SelectByTicket(ticket)) continue;
      if(posInfo.Symbol()==g_symbol && posInfo.Magic()==InpMagic)
         trade.PositionClose(ticket);
   }
}

int CurrentDayOfYear()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return(dt.day_of_year);
}

void Notify(string msg)
{
   Print(msg);
   if(InpEnableAlerts) Alert(msg);
   if(InpPushNotify)   SendNotification(msg);
}
//+------------------------------------------------------------------+
