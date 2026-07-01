//+------------------------------------------------------------------+
//|                                                       FUSION.mq5  |
//|        FUSION - Fully Unified System for Intelligent Order Nav.   |
//|        Trader o'zi qoida quradigan, to'liq sozlanadigan robot     |
//+------------------------------------------------------------------+
#property copyright "FUSION EA"
#property link      ""
#property version   "2.00"
#property description "FUSION - to'liq sozlanadigan MT5 robot. 2 rejim:"
#property description "PRESET (7 tayyor strategiya) yoki CUSTOM (trader o'zi qoida quradi)."
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
   PRESET_BOLLINGER_BOUNCE, // Bollinger bounce (chiziqqa tegish)
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
   g_tf = (InpEntryTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpEntryTF;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   if(!symInfo.Name(_Symbol))
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

   Print("FUSION EA ishga tushdi. Symbol=", _Symbol, " TF=", EnumToString(g_tf));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { }

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

      //--- 4) Bollinger Bounce: narx pastki chiziqdan past -> BUY ---
      case PRESET_BOLLINGER_BOUNCE:
         LoadCond(g_buy[0],  true, IND_PRICE, 0, OP_LESS,    CMP_IND, 0, IND_BB_LOWER, InpPR_BB_Period);
         LoadCond(g_sell[0], true, IND_PRICE, 0, OP_GREATER, CMP_IND, 0, IND_BB_UPPER, InpPR_BB_Period);
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

   // Ochiq pozitsiyalarni boshqarish (har tickda)
   ManageOpenPositions();

   // Faqat yangi bar ochilganda signal tekshiriladi (agar OnePerBar=true)
   datetime curBar = iTime(_Symbol, g_tf, 0);
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

   // Maksimal pozitsiya soni
   if(CountPositions() >= InpMaxPositions)
      return;

   // Signal hisoblash
   bool buySignal  = EvaluateSide(g_buy,  g_buyLogic,  g_buyVotes);
   bool sellSignal = EvaluateSide(g_sell, g_sellLogic, g_sellVotes);

   // Qarama-qarshi signalda yopish
   if(InpExitMode == EXIT_OPPOSITE_SIGNAL || InpExitMode == EXIT_BOTH)
   {
      if(buySignal)  ClosePositionsByType(POSITION_TYPE_SELL);
      if(sellSignal) ClosePositionsByType(POSITION_TYPE_BUY);
   }

   // Bir vaqtda ikkalasi ham signal bersa - savdo qilmaymiz (ziddiyat)
   if(buySignal && sellSignal)
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
   double a0, a1; // indikator A: shift 0 va shift 1 (cross uchun)
   double b0, b1; // taqqoslash tomoni

   if(!GetIndValue(c.indA, c.perA, 0, a0)) return(false);
   if(!GetIndValue(c.indA, c.perA, 1, a1)) return(false);

   if(c.cmp==CMP_VALUE)
   {
      b0 = c.val;
      b1 = c.val;
   }
   else // CMP_IND
   {
      if(c.indB==IND_NONE) return(false);
      if(!GetIndValue(c.indB, c.perB, 0, b0)) return(false);
      if(!GetIndValue(c.indB, c.perB, 1, b1)) return(false);
   }

   switch(c.op)
   {
      case OP_GREATER:     return(a0 > b0);
      case OP_LESS:        return(a0 < b0);
      case OP_CROSS_ABOVE: return(a1 <= b1 && a0 > b0);
      case OP_CROSS_BELOW: return(a1 >= b1 && a0 < b0);
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
   int handle=INVALID_HANDLE;
   double buf[];

   switch(ind)
   {
      case IND_PRICE:
         out = iClose(_Symbol, g_tf, shift);
         return(out>0);

      case IND_MA:
         handle = iMA(_Symbol, g_tf, period, 0, MODE_EMA, PRICE_CLOSE);
         break;
      case IND_RSI:
         handle = iRSI(_Symbol, g_tf, period, PRICE_CLOSE);
         break;
      case IND_MACD_MAIN:
      case IND_MACD_SIGNAL:
         handle = iMACD(_Symbol, g_tf, 12, 26, 9, PRICE_CLOSE);
         break;
      case IND_STOCH:
         handle = iStochastic(_Symbol, g_tf, period, 3, 3, MODE_SMA, STO_LOWHIGH);
         break;
      case IND_CCI:
         handle = iCCI(_Symbol, g_tf, period, PRICE_TYPICAL);
         break;
      case IND_ADX:
         handle = iADX(_Symbol, g_tf, period);
         break;
      case IND_ATR:
         handle = iATR(_Symbol, g_tf, period);
         break;
      case IND_BB_UPPER:
      case IND_BB_LOWER:
         handle = iBands(_Symbol, g_tf, period, 0, 2.0, PRICE_CLOSE);
         break;
      default:
         return(false);
   }

   if(handle==INVALID_HANDLE) return(false);

   int bufIndex = 0;
   if(ind==IND_MACD_SIGNAL) bufIndex = 1; // signal liniya
   if(ind==IND_BB_UPPER)    bufIndex = 1; // upper band
   if(ind==IND_BB_LOWER)    bufIndex = 2; // lower band

   if(CopyBuffer(handle, bufIndex, shift, 1, buf) < 1)
   {
      IndicatorRelease(handle);
      return(false);
   }
   out = buf[0];
   IndicatorRelease(handle);
   return(true);
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
      slPts = InpStopLossPoints;
      tpPts = InpTakeProfitPoints;
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
         slPts = InpStopLossPoints; // zaxira
         tpPts = InpTakeProfitPoints;
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
      ok = trade.Buy(lot, _Symbol, 0.0, sl, tp, InpComment);
   else
      ok = trade.Sell(lot, _Symbol, 0.0, sl, tp, InpComment);

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
   double lot = InpFixedLot;

   if(InpLotMode==LOT_RISK_PERCENT && slPts>0)
   {
      double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * InpRiskPercent / 100.0;
      double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
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
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

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
      if(posInfo.Symbol()!=_Symbol) continue;
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
   return((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
}

int CountPositions()
{
   int cnt=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!posInfo.SelectByTicket(ticket)) continue;
      if(posInfo.Symbol()==_Symbol && posInfo.Magic()==InpMagic) cnt++;
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
      if(posInfo.Symbol()==_Symbol && posInfo.Magic()==InpMagic && posInfo.PositionType()==ptype)
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
      if(posInfo.Symbol()==_Symbol && posInfo.Magic()==InpMagic)
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
