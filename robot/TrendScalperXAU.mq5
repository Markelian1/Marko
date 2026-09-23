//+------------------------------------------------------------------+
//|                                             TrendScalperXAU.mq5  |
//|  Robot per XAUUSD me te njejten logjike si TrendScalperXAU.pine  |
//|                                                                  |
//|  Dy lloje hyrjesh (ne grafikun e hyrjes, parazgjedhur M1):       |
//|  1. TREND: pullback te EMA 20 ne drejtim te trendit nga 3        |
//|     timeframe (H1, M15, M5). M5 kunder H1 = KTHIM (vetem TP1).   |
//|  2. SWEEP: cmimi kalon me bisht nje fund/maje (likuiditet) dhe   |
//|     mbyllet mbrapa nivelit -> hyrje ne anen e kundert,           |
//|     pavaresisht trendit. Mbyll edhe pozicionin e kundert.        |
//|                                                                  |
//|  Cdo hyrje = 2 pozicione: TP1 20 pips, TP2 50 pips,              |
//|  break-even pas TP1. Lot fiks, PA martingale.                    |
//+------------------------------------------------------------------+
#property copyright "Marko"
#property version   "2.00"
#property description "Scalper per ar: hyrje TREND (3 timeframe) dhe SWEEP (likuiditet), pa martingale."

#include <Trade\Trade.mqh>

input group "Madhesia e pozicionit"
input double InpLots            = 0.01;   // Loti per secilin nga 2 pozicionet
input double InpPipSize         = 0.10;   // 1 pip ne ar = 0.10$ levizje cmimi

input group "TP / SL (ne pips)"
input int    InpTP1Pips         = 20;     // TP i pozicionit 1
input int    InpTP2Pips         = 50;     // TP i pozicionit 2
input int    InpSLPips          = 30;     // SL per hyrjet TREND
input bool   InpBreakEven       = true;   // Pas TP1, SL e pozicionit 2 ne hyrje
input int    InpBEOffsetPips    = 1;      // Sa pips mbi hyrje (mbulon komisionin)

input group "Grafiku i hyrjes"
input ENUM_TIMEFRAMES InpEntryTF = PERIOD_M1;

input group "Hyrjet TREND (3 timeframe)"
input bool   InpUseTrend        = true;
input ENUM_TIMEFRAMES InpTFHigh = PERIOD_H1;   // Trendi kryesor
input ENUM_TIMEFRAMES InpTFMid  = PERIOD_M15;  // Trendi i mesem
input ENUM_TIMEFRAMES InpTFLow  = PERIOD_M5;   // Trendi i shpejte
input int    InpFastEMA         = 21;
input int    InpSlowEMA         = 50;
input bool   InpAllowKthim      = true;   // Lejo hyrje ne kthime (kunder trendit kryesor)
input bool   InpKthimTP1Only    = true;   // Ne kthime te dy pozicionet mbyllen ne TP1
input int    InpEntryEMA        = 20;     // EMA e pullback-ut

input group "Hyrjet SWEEP (likuiditet)"
input bool   InpUseSweep        = true;
input int    InpPivotLen        = 3;      // Forca e swing-ut (qirinj majtas/djathtas)
input int    InpEqTolPips       = 20;     // Toleranca per fundet/majat e barabarta
input bool   InpNeedEqual       = false;  // Vetem nivele te dyfishta (equal lows/highs)
input int    InpMaxSweepPips    = 30;     // Me thelle se kaq = thyerje, jo sweep
input int    InpConfBars        = 2;      // Qirinj per t'u kthyer mbrapa nivelit
input bool   InpNeedBody        = true;   // Qiriri i hyrjes ne drejtim te tregtimit
input int    InpSweepSLBuf      = 5;      // SL pas bishtit (pips)
input int    InpSweepMinSL      = 15;     // SL minimal (pips)
input int    InpSweepMaxSL      = 40;     // SL maksimal: me i madh = pa hyrje
input bool   InpFlipOpposite    = true;   // Sweep-i mbyll pozicionin e kundert

input group "Kufizime"
input int    InpMaxSpreadPips   = 4;      // Mos hyj nese spread-i eshte me i madh
input int    InpStartHour       = 3;      // Ora e serverit kur fillon
input int    InpEndHour         = 21;     // Ora e serverit kur ndalon hyrjet e reja
input double InpDailyProfitStop = 0;      // Ndalo per sot pas ketij fitimi (0 = pa limit)
input double InpDailyLossStop   = 12;     // Ndalo per sot pas kesaj humbjeje (0 = pa limit)
input int    InpMaxSetupsPerDay = 10;     // Sa hyrje (me nga 2 pozicione) ne dite
input ulong  InpMagic           = 20260923;

CTrade          trade;
ENUM_TIMEFRAMES g_tfs[3];
int             hFast[3];
int             hSlow[3];
int             hEntryEMA = INVALID_HANDLE;
datetime        g_lastBarTime = 0;

// Nivelet e likuiditetit
double g_loLvl[];
int    g_loCnt[];
double g_hiLvl[];
int    g_hiCnt[];

// Sweep-et ne pritje te mbylljes mbrapa nivelit
long   g_barNo    = 0;
bool   g_pBuy     = false;
double g_pBuyLvl  = 0, g_pBuyLow = 0;
long   g_pBuyExp  = 0;
bool   g_pSell    = false;
double g_pSellLvl = 0, g_pSellHi = 0;
long   g_pSellExp = 0;

// Sinjalet e qiririt te fundit te mbyllur
bool   g_sweepBuy  = false;
bool   g_sweepSell = false;
double g_sigLow    = 0;
double g_sigHigh   = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpTP1Pips <= 0 || InpTP2Pips <= InpTP1Pips || InpSLPips <= 0 || InpPipSize <= 0 || InpPivotLen < 1)
   {
      Print("Parametra te gabuar: duhet TP2 > TP1 > 0, SL > 0, PipSize > 0 dhe PivotLen >= 1");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_tfs[0] = InpTFHigh;
   g_tfs[1] = InpTFMid;
   g_tfs[2] = InpTFLow;
   for(int i = 0; i < 3; i++)
   {
      hFast[i] = iMA(_Symbol, g_tfs[i], InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
      hSlow[i] = iMA(_Symbol, g_tfs[i], InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(hFast[i] == INVALID_HANDLE || hSlow[i] == INVALID_HANDLE)
      {
         Print("Nuk u krijuan indikatoret EMA te trendit");
         return INIT_FAILED;
      }
   }
   hEntryEMA = iMA(_Symbol, InpEntryTF, InpEntryEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hEntryEMA == INVALID_HANDLE)
   {
      Print("Nuk u krijua EMA e hyrjes");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < 3; i++)
   {
      if(hFast[i] != INVALID_HANDLE) IndicatorRelease(hFast[i]);
      if(hSlow[i] != INVALID_HANDLE) IndicatorRelease(hSlow[i]);
   }
   if(hEntryEMA != INVALID_HANDLE) IndicatorRelease(hEntryEMA);
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageBreakEven();

   // Sinjalet kontrollohen vetem kur mbyllet nje qiri ne grafikun e hyrjes
   datetime barTime = iTime(_Symbol, InpEntryTF, 0);
   if(barTime == 0 || barTime == g_lastBarTime)
      return;
   bool firstRun = (g_lastBarTime == 0);
   g_lastBarTime = barTime;

   if(firstRun)
      Warmup();          // nderton nivelet e likuiditetit nga historia
   ProcessBar(1);

   // Trendi nga 3 timeframe
   int  tH       = TFTrend(0);
   int  tM       = TFTrend(1);
   int  tL       = TFTrend(2);
   int  baseDir  = (tL != 0 && tM != -tL) ? tL : 0;
   bool isKthim  = (baseDir != 0 && tH == -baseDir);
   int  tradeDir = (isKthim && !InpAllowKthim) ? 0 : baseDir;
   int  trendSig = InpUseTrend ? GetTrendSignal(tradeDir) : 0;

   int sweepDir = (g_sweepBuy != g_sweepSell) ? (g_sweepBuy ? 1 : -1) : 0;

   // Sweep ne anen e kundert: mbyll pozicionet e hapura
   if(InpFlipOpposite && sweepDir != 0 && MyPositionsDir() == -sweepDir)
      CloseMyPositions();

   if(CountMyPositions() > 0) return;   // nje hyrje ne te njejten kohe
   if(!IsTradingHour())       return;
   if(!IsSpreadOk())          return;
   if(!AreDailyLimitsOk())    return;

   // SWEEP ka perparesi para TREND
   if(sweepDir != 0)
   {
      double pip   = InpPipSize;
      double price = sweepDir > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ref   = sweepDir > 0 ? g_sigLow - InpSweepSLBuf * pip : g_sigHigh + InpSweepSLBuf * pip;
      double slP   = MathMax(InpSweepMinSL, sweepDir * (price - ref) / pip);
      if(slP <= InpSweepMaxSL)
         OpenSetup(sweepDir, slP, false, "SWEEP");
      return;
   }

   if(trendSig != 0)
      OpenSetup(trendSig, InpSLPips, isKthim && InpKthimTP1Only, isKthim ? "KTHIM" : "TREND");
}

//+------------------------------------------------------------------+
//| +1 = lart, -1 = poshte, 0 = pa drejtim (vetem qirinj te mbyllur)  |
//+------------------------------------------------------------------+
int TFTrend(const int i)
{
   double f[1], s[1];
   if(CopyBuffer(hFast[i], 0, 1, 1, f) != 1) return 0;
   if(CopyBuffer(hSlow[i], 0, 1, 1, s) != 1) return 0;
   double c = iClose(_Symbol, g_tfs[i], 1);
   if(c == 0) return 0;

   if(f[0] > s[0] && c > f[0]) return  1;
   if(f[0] < s[0] && c < f[0]) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Pullback: qiriri i fundit preku EMA 20 dhe u mbyll ne drejtim te  |
//| trendit (buy: qiri jeshil mbi EMA, sell: qiri i kuq nen EMA).     |
//+------------------------------------------------------------------+
int GetTrendSignal(const int trend)
{
   if(trend == 0) return 0;
   double ema[1];
   if(CopyBuffer(hEntryEMA, 0, 1, 1, ema) != 1) return 0;

   double o = iOpen (_Symbol, InpEntryTF, 1);
   double h = iHigh (_Symbol, InpEntryTF, 1);
   double l = iLow  (_Symbol, InpEntryTF, 1);
   double c = iClose(_Symbol, InpEntryTF, 1);
   if(o == 0 || c == 0) return 0;

   if(trend > 0 && l <= ema[0] && c > ema[0] && c > o) return  1;
   if(trend < 0 && h >= ema[0] && c < ema[0] && c < o) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Kalon historine qe nivelet e likuiditetit te jene gati qe ne     |
//| fillim. Sinjalet e historise injorohen.                           |
//+------------------------------------------------------------------+
void Warmup()
{
   int bars  = Bars(_Symbol, InpEntryTF);
   int start = MathMin(300, bars - 2 * InpPivotLen - 2);
   for(int s = start; s >= 2; s--)
      ProcessBar(s);
}

//+------------------------------------------------------------------+
//| Perpunon qiririn e mbyllur ne shift s: nivele te reja, sweep-e    |
//| dhe sinjali SWEEP (g_sweepBuy / g_sweepSell).                     |
//+------------------------------------------------------------------+
void ProcessBar(const int s)
{
   g_barNo++;
   g_sweepBuy  = false;
   g_sweepSell = false;

   double pip = InpPipSize;

   // Swing i ri i konfirmuar (qiriri s + PivotLen)
   int p = s + InpPivotLen;
   if(IsPivotLow(p))
      AddLevel(g_loLvl, g_loCnt, iLow(_Symbol, InpEntryTF, p), true);
   if(IsPivotHigh(p))
      AddLevel(g_hiLvl, g_hiCnt, iHigh(_Symbol, InpEntryTF, p), false);

   double o = iOpen (_Symbol, InpEntryTF, s);
   double h = iHigh (_Symbol, InpEntryTF, s);
   double l = iLow  (_Symbol, InpEntryTF, s);
   double c = iClose(_Symbol, InpEntryTF, s);
   if(c == 0) return;

   if(g_pBuy  && g_barNo > g_pBuyExp)  g_pBuy  = false;
   if(g_pSell && g_barNo > g_pSellExp) g_pSell = false;

   int needCnt = InpNeedEqual ? 2 : 1;

   // Fundet qe u kaluan: likuiditeti poshte u mor
   for(int k = ArraySize(g_loLvl) - 1; k >= 0; k--)
   {
      double lvl = g_loLvl[k];
      if(l < lvl)
      {
         if(g_loCnt[k] >= needCnt && lvl - l <= InpMaxSweepPips * pip)
         {
            g_pBuyLvl = g_pBuy ? MathMin(g_pBuyLvl, lvl) : lvl;
            g_pBuyLow = g_pBuy ? MathMin(g_pBuyLow, l) : l;
            g_pBuy    = true;
            g_pBuyExp = g_barNo + InpConfBars;
         }
         RemoveLevel(g_loLvl, g_loCnt, k);
      }
   }

   // Majat qe u kaluan: likuiditeti lart u mor
   for(int k = ArraySize(g_hiLvl) - 1; k >= 0; k--)
   {
      double lvl = g_hiLvl[k];
      if(h > lvl)
      {
         if(g_hiCnt[k] >= needCnt && h - lvl <= InpMaxSweepPips * pip)
         {
            g_pSellLvl = g_pSell ? MathMax(g_pSellLvl, lvl) : lvl;
            g_pSellHi  = g_pSell ? MathMax(g_pSellHi, h) : h;
            g_pSell    = true;
            g_pSellExp = g_barNo + InpConfBars;
         }
         RemoveLevel(g_hiLvl, g_hiCnt, k);
      }
   }

   // Nese cmimi vazhdon shume pertej nivelit, eshte thyerje e vertete
   if(g_pBuy)
   {
      g_pBuyLow = MathMin(g_pBuyLow, l);
      if(g_pBuyLvl - g_pBuyLow > InpMaxSweepPips * pip) g_pBuy = false;
   }
   if(g_pSell)
   {
      g_pSellHi = MathMax(g_pSellHi, h);
      if(g_pSellHi - g_pSellLvl > InpMaxSweepPips * pip) g_pSell = false;
   }

   // Sinjali: mbyllje perseri mbrapa nivelit qe u mor
   if(InpUseSweep && g_pBuy && c > g_pBuyLvl && (!InpNeedBody || c > o))
   {
      g_sweepBuy = true;
      g_sigLow   = g_pBuyLow;
      g_pBuy     = false;
   }
   if(InpUseSweep && g_pSell && c < g_pSellLvl && (!InpNeedBody || c < o))
   {
      g_sweepSell = true;
      g_sigHigh   = g_pSellHi;
      g_pSell     = false;
   }
}

//+------------------------------------------------------------------+
bool IsPivotLow(const int p)
{
   double v = iLow(_Symbol, InpEntryTF, p);
   if(v == 0) return false;
   for(int j = 1; j <= InpPivotLen; j++)
   {
      double left  = iLow(_Symbol, InpEntryTF, p + j);
      double right = iLow(_Symbol, InpEntryTF, p - j);
      if(left == 0 || left <= v || right < v) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool IsPivotHigh(const int p)
{
   double v = iHigh(_Symbol, InpEntryTF, p);
   if(v == 0) return false;
   for(int j = 1; j <= InpPivotLen; j++)
   {
      double left  = iHigh(_Symbol, InpEntryTF, p + j);
      double right = iHigh(_Symbol, InpEntryTF, p - j);
      if(left == 0 || left >= v || right > v) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Nivel i ri likuiditeti; bashkohet me nje nivel afer (equal lows)  |
//+------------------------------------------------------------------+
void AddLevel(double &lvl[], int &cnt[], const double price, const bool isLow)
{
   int n = ArraySize(lvl);
   for(int k = 0; k < n; k++)
   {
      if(MathAbs(lvl[k] - price) <= InpEqTolPips * InpPipSize)
      {
         lvl[k] = isLow ? MathMin(lvl[k], price) : MathMax(lvl[k], price);
         cnt[k]++;
         return;
      }
   }
   if(n >= 12)
   {
      RemoveLevel(lvl, cnt, 0);
      n--;
   }
   ArrayResize(lvl, n + 1);
   ArrayResize(cnt, n + 1);
   lvl[n] = price;
   cnt[n] = 1;
}

//+------------------------------------------------------------------+
void RemoveLevel(double &lvl[], int &cnt[], const int idx)
{
   int n = ArraySize(lvl);
   for(int k = idx; k < n - 1; k++)
   {
      lvl[k] = lvl[k + 1];
      cnt[k] = cnt[k + 1];
   }
   ArrayResize(lvl, n - 1);
   ArrayResize(cnt, n - 1);
}

//+------------------------------------------------------------------+
//| Hap 2 pozicione me te njejtin SL: njeri me TP1, tjetri me TP2.    |
//| tp1Only: te dy mbyllen ne TP1 (hyrjet KTHIM).                     |
//+------------------------------------------------------------------+
void OpenSetup(const int dir, const double slPips, const bool tp1Only, const string tag)
{
   double lots = NormalizeLots(InpLots);
   double pip  = InpPipSize;
   double tp2Pips = tp1Only ? InpTP1Pips : InpTP2Pips;

   if(dir > 0)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = NormalizeDouble(price - slPips     * pip, _Digits);
      double tp1 = NormalizeDouble(price + InpTP1Pips * pip, _Digits);
      double tp2 = NormalizeDouble(price + tp2Pips    * pip, _Digits);

      if(!trade.Buy(lots, _Symbol, 0, sl, tp1, tag + " TP1"))
      {
         Print("Buy ", tag, " TP1 deshtoi: ", trade.ResultRetcodeDescription());
         return;   // pa TP1 nuk hapim as TP2
      }
      if(!trade.Buy(lots, _Symbol, 0, sl, tp2, tag + " TP2"))
         Print("Buy ", tag, " TP2 deshtoi: ", trade.ResultRetcodeDescription());
   }
   else
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = NormalizeDouble(price + slPips     * pip, _Digits);
      double tp1 = NormalizeDouble(price - InpTP1Pips * pip, _Digits);
      double tp2 = NormalizeDouble(price - tp2Pips    * pip, _Digits);

      if(!trade.Sell(lots, _Symbol, 0, sl, tp1, tag + " TP1"))
      {
         Print("Sell ", tag, " TP1 deshtoi: ", trade.ResultRetcodeDescription());
         return;
      }
      if(!trade.Sell(lots, _Symbol, 0, sl, tp2, tag + " TP2"))
         Print("Sell ", tag, " TP2 deshtoi: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Kur mbetet vetem pozicioni TP2 (TP1 u mor), SL kalon ne hyrje     |
//+------------------------------------------------------------------+
void ManageBreakEven()
{
   if(!InpBreakEven || CountMyPositions() != 1)
      return;

   double pip      = InpPipSize;
   double minStop  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsMyPosition()) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      long   type = PositionGetInteger(POSITION_TYPE);

      // Vetem pozicioni me TP te larget (TP2)
      if(tp == 0 || MathAbs(tp - open) / pip < (InpTP1Pips + InpTP2Pips) / 2.0)
         continue;

      if(type == POSITION_TYPE_BUY)
      {
         double newSL = NormalizeDouble(open + InpBEOffsetPips * pip, _Digits);
         double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(sl < newSL && bid - newSL > minStop)
            if(!trade.PositionModify(ticket, newSL, tp))
               Print("Break-even deshtoi: ", trade.ResultRetcodeDescription());
      }
      else
      {
         double newSL = NormalizeDouble(open - InpBEOffsetPips * pip, _Digits);
         double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if((sl == 0 || sl > newSL) && newSL - ask > minStop)
            if(!trade.PositionModify(ticket, newSL, tp))
               Print("Break-even deshtoi: ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| 1 = robot ka buy te hapura, -1 = sell, 0 = asgje                  |
//+------------------------------------------------------------------+
int MyPositionsDir()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsMyPosition()) continue;
      return PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
   }
   return 0;
}

//+------------------------------------------------------------------+
void CloseMyPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsMyPosition()) continue;
      if(!trade.PositionClose(ticket))
         Print("Mbyllja deshtoi: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Kufijte ditore: fitimi/humbja e mbyllur sot dhe numri i hyrjeve   |
//+------------------------------------------------------------------+
bool AreDailyLimitsOk()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   t.hour = 0; t.min = 0; t.sec = 0;
   datetime dayStart = StructToTime(t);

   if(!HistorySelect(dayStart, TimeCurrent() + 60))
      return true;

   double pl      = 0;
   int    entries = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != (long)InpMagic) continue;

      if(HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         entries++;
      pl += HistoryDealGetDouble(deal, DEAL_PROFIT)
          + HistoryDealGetDouble(deal, DEAL_COMMISSION)
          + HistoryDealGetDouble(deal, DEAL_SWAP);
   }

   if(InpDailyProfitStop > 0 && pl >= InpDailyProfitStop)             return false;
   if(InpDailyLossStop   > 0 && pl <= -InpDailyLossStop)              return false;
   if(InpMaxSetupsPerDay > 0 && (entries + 1) / 2 >= InpMaxSetupsPerDay) return false;
   return true;
}

//+------------------------------------------------------------------+
bool IsTradingHour()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   if(InpStartHour <= InpEndHour)
      return t.hour >= InpStartHour && t.hour < InpEndHour;
   return t.hour >= InpStartHour || t.hour < InpEndHour;   // orar pertej mesnates
}

//+------------------------------------------------------------------+
bool IsSpreadOk()
{
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return spread / InpPipSize <= InpMaxSpreadPips;
}

//+------------------------------------------------------------------+
//| Pozicioni i zgjedhur aktualisht eshte i ketij roboti?             |
//+------------------------------------------------------------------+
bool IsMyPosition()
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol
       && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic;
}

//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(IsMyPosition()) count++;
   }
   return count;
}

//+------------------------------------------------------------------+
double NormalizeLots(const double lots)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double v = MathFloor(lots / stepLot + 1e-9) * stepLot;
   return MathMax(minLot, MathMin(maxLot, v));
}
//+------------------------------------------------------------------+
