//+------------------------------------------------------------------+
//|                                                  KeyLevelXAU.mq5 |
//|  Robot per XAUUSD qe hyn VETEM te nivelet kyce, si tregtimi       |
//|  manual: SELL te rezistenca, BUY te mbeshtetja.                   |
//|                                                                  |
//|  1. Nivelet kyce: majat/fundet e rendesishme ne M15 (2 ditet e    |
//|     fundit) + High/Low e dites se kaluar.                         |
//|  2. Cmimi arrin nivelin (ose e kalon me bisht, sweep).            |
//|  3. Konfirmimi ne M1: qiriri mbyllet perseri mbrapa nivelit dhe   |
//|     thyen strukturen e vogel (min/max e 3 qirinjve te fundit).    |
//|  4. SL pas bishtit. TP = niveli kyc tjeter. Hyr vetem nese ka     |
//|     hapesire te pakten 2R deri te niveli tjeter.                  |
//|  5. 2 pozicione kur objektivi eshte >= 3R (TP1 = 1R + TP2 te      |
//|     niveli), perndryshe 1 pozicion. Cdo nivel perdoret nje here.  |
//|  Lot fiks, PA martingale.                                         |
//+------------------------------------------------------------------+
#property copyright "Marko"
#property version   "1.00"
#property description "Hyrje vetem te nivelet kyce pas reagimit te konfirmuar. 1 ose 2 pozicione, pa martingale."

#include <Trade\Trade.mqh>

input group "Madhesia e pozicionit"
input double InpLots            = 0.01;   // Loti per cdo pozicion
input double InpPipSize         = 0.10;   // 1 pip ne ar = 0.10$ levizje cmimi

input group "Nivelet kyce"
input ENUM_TIMEFRAMES InpLevelTF = PERIOD_M15;
input int    InpLevelPivot      = 5;      // Forca e majes/fundit (qirinj majtas/djathtas)
input int    InpLevelLookback   = 192;    // Sa qirinj mbrapa (192 x M15 = 2 dite)
input int    InpLevelMergePips  = 30;     // Nivele me afer se kaq bashkohen ne nje
input bool   InpUsePrevDay      = true;   // Perfshi High/Low e dites se kaluar
input bool   InpDrawLevels      = true;   // Vizato nivelet ne grafik

input group "Hyrja"
input ENUM_TIMEFRAMES InpEntryTF = PERIOD_M1;
input int    InpZonePips        = 15;     // Sa afer nivelit quhet prekje
input int    InpMaxSweepPips    = 40;     // Me thelle se kaq pertej nivelit = niveli u thye
input int    InpConfirmBars     = 15;     // Brenda sa qirinjve pas prekjes duhet konfirmimi
input int    InpMssBars         = 3;      // Konfirmimi: mbyllje pertej min/max te kaq qirinjve
input bool   InpNeedBody        = true;   // Qiriri i konfirmimit ne drejtim te tregtimit

input group "SL / TP"
input int    InpSLBufPips       = 5;      // SL pas bishtit (pips)
input int    InpMinSLPips       = 20;     // SL minimal
input int    InpMaxSLPips       = 60;     // SL maksimal: me i madh = pa hyrje
input double InpMinRR           = 2.0;    // Niveli tjeter duhet te jete te pakten kaq R larg
input double InpFallbackRR      = 2.0;    // TP kur nuk ka nivel tjeter (ne R)
input int    InpTPBufPips       = 3;      // TP pak para nivelit tjeter
input double InpTwoPosRR        = 3.0;    // 2 pozicione vetem kur objektivi >= kaq R
input double InpTP1R            = 1.0;    // TP1 i pozicionit te pare (ne R)
input bool   InpSellSpreadAdj   = true;   // SELL: SL/TP zhvendosen me spread-in (mbyllen kur Bid, cmimi ne grafik, i prek)
input bool   InpBreakEven       = true;   // Pas TP1, SL e pozicionit 2 ne hyrje
input int    InpBEOffsetPips    = 1;

input group "Kufizime"
input int    InpStartHour       = 9;      // Ora e serverit (London)
input int    InpEndHour         = 21;     // Ora e serverit (fundi i New York)
input int    InpMaxSpreadPips   = 4;
input int    InpMaxTradesPerDay = 4;      // Hyrje ne dite (0 = pa limit)
input double InpDailyLossStop   = 0;      // Ndalo per sot pas kesaj humbjeje (0 = pa limit)
input ulong  InpMagic           = 20260924;

struct Watch
{
   bool   active;
   int    dir;       // 1 = BUY te mbeshtetja, -1 = SELL te rezistenca
   double level;
   double extreme;   // bishti me i larget pas prekjes
   long   start;
};

CTrade   trade;
double   g_levels[];
double   g_used[];          // nivelet e perdorura/thyera sot
int      g_usedDay      = -1;
datetime g_lastEntryBar = 0;
datetime g_lastLevelBar = 0;
long     g_barNo        = 0;
Watch    g_watch[2];        // 0 = BUY, 1 = SELL
double   g_sigLevel     = 0;
double   g_sigExtreme   = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpPipSize <= 0 || InpLevelPivot < 1 || InpMinSLPips <= 0 || InpMaxSLPips < InpMinSLPips || InpMssBars < 1)
   {
      Print("Parametra te gabuar");
      return INIT_PARAMETERS_INCORRECT;
   }
   for(int i = 0; i < 2; i++)
      g_watch[i].active = false;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "KL_");
   PrintStats();
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageBreakEven();

   // Nivelet rindertohen ne cdo qiri te ri M15
   datetime lt = iTime(_Symbol, InpLevelTF, 0);
   if(lt != 0 && lt != g_lastLevelBar)
   {
      g_lastLevelBar = lt;
      ResetUsedIfNewDay();
      BuildLevels();
   }

   // Hyrjet kontrollohen ne cdo qiri te mbyllur M1
   datetime bt = iTime(_Symbol, InpEntryTF, 0);
   if(bt == 0 || bt == g_lastEntryBar)
      return;
   g_lastEntryBar = bt;
   g_barNo++;
   ResetUsedIfNewDay();

   int sig = UpdateWatches();
   if(sig == 0) return;

   if(CountMyPositions() > 0) return;
   if(!IsTradingHour())       return;
   if(!IsSpreadOk())          return;
   if(!AreDailyLimitsOk())    return;

   OpenTrade(sig, g_sigExtreme);
}

//+------------------------------------------------------------------+
//| Nivelet kyce: majat/fundet ne M15 + High/Low e dites se kaluar    |
//+------------------------------------------------------------------+
void BuildLevels()
{
   ArrayResize(g_levels, 0);

   // Nga me i fundit te me i vjetri: nivelet e reja kane perparesi
   for(int p = InpLevelPivot + 1; p <= InpLevelLookback; p++)
   {
      if(IsLevelPivot(p, true))  AddLevel(iHigh(_Symbol, InpLevelTF, p));
      if(IsLevelPivot(p, false)) AddLevel(iLow (_Symbol, InpLevelTF, p));
   }
   if(InpUsePrevDay)
   {
      AddLevel(iHigh(_Symbol, PERIOD_D1, 1));
      AddLevel(iLow (_Symbol, PERIOD_D1, 1));
   }

   if(InpDrawLevels)
   {
      ObjectsDeleteAll(0, "KL_");
      for(int i = 0; i < ArraySize(g_levels); i++)
      {
         string name = "KL_" + IntegerToString(i);
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, g_levels[i]);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      }
   }
}

//+------------------------------------------------------------------+
bool IsLevelPivot(const int p, const bool isHigh)
{
   double v = isHigh ? iHigh(_Symbol, InpLevelTF, p) : iLow(_Symbol, InpLevelTF, p);
   if(v == 0) return false;
   for(int j = 1; j <= InpLevelPivot; j++)
   {
      double left  = isHigh ? iHigh(_Symbol, InpLevelTF, p + j) : iLow(_Symbol, InpLevelTF, p + j);
      double right = isHigh ? iHigh(_Symbol, InpLevelTF, p - j) : iLow(_Symbol, InpLevelTF, p - j);
      if(left == 0) return false;
      if(isHigh  && (left >= v || right > v)) return false;
      if(!isHigh && (left <= v || right < v)) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void AddLevel(const double price)
{
   if(price <= 0) return;
   double merge = InpLevelMergePips * InpPipSize;
   for(int i = 0; i < ArraySize(g_levels); i++)
      if(MathAbs(g_levels[i] - price) <= merge) return;
   for(int i = 0; i < ArraySize(g_used); i++)
      if(MathAbs(g_used[i] - price) <= merge) return;
   int n = ArraySize(g_levels);
   ArrayResize(g_levels, n + 1);
   g_levels[n] = price;
}

//+------------------------------------------------------------------+
//| Niveli u perdor ose u thye: nuk tregtohet me sot                  |
//+------------------------------------------------------------------+
void MarkUsed(const double price)
{
   int n = ArraySize(g_used);
   ArrayResize(g_used, n + 1);
   g_used[n] = price;

   double merge = InpLevelMergePips * InpPipSize;
   for(int i = ArraySize(g_levels) - 1; i >= 0; i--)
   {
      if(MathAbs(g_levels[i] - price) > merge) continue;
      for(int k = i; k < ArraySize(g_levels) - 1; k++)
         g_levels[k] = g_levels[k + 1];
      ArrayResize(g_levels, ArraySize(g_levels) - 1);
   }
}

//+------------------------------------------------------------------+
void ResetUsedIfNewDay()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   if(t.day_of_year != g_usedDay)
   {
      g_usedDay = t.day_of_year;
      ArrayResize(g_used, 0);
   }
}

//+------------------------------------------------------------------+
//| Ndjek prekjet e niveleve dhe kthen +1/-1 kur konfirmohet hyrja    |
//+------------------------------------------------------------------+
int UpdateWatches()
{
   double pip   = InpPipSize;
   double tol   = InpZonePips * pip;
   double o     = iOpen (_Symbol, InpEntryTF, 1);
   double h     = iHigh (_Symbol, InpEntryTF, 1);
   double l     = iLow  (_Symbol, InpEntryTF, 1);
   double c     = iClose(_Symbol, InpEntryTF, 1);
   double prevC = iClose(_Symbol, InpEntryTF, 2);
   if(c == 0 || prevC == 0) return 0;

   // Prekje e re: rezistenca prekur nga poshte, mbeshtetja nga lart
   for(int i = 0; i < ArraySize(g_levels); i++)
   {
      double L = g_levels[i];
      if(!g_watch[1].active && prevC < L && h >= L - tol)
         StartWatch(1, -1, L, h);
      if(!g_watch[0].active && prevC > L && l <= L + tol)
         StartWatch(0, 1, L, l);
   }

   int result = 0;
   for(int s = 0; s < 2; s++)
   {
      if(!g_watch[s].active) continue;
      int    d = g_watch[s].dir;
      double L = g_watch[s].level;

      if(g_barNo - g_watch[s].start > InpConfirmBars)
      {
         g_watch[s].active = false;       // nuk erdhi konfirmimi
         continue;
      }

      g_watch[s].extreme = d < 0 ? MathMax(g_watch[s].extreme, h) : MathMin(g_watch[s].extreme, l);

      // Niveli u thye me te vertete: nuk e tregtojme me
      bool broken = d < 0 ? (c > L + InpMaxSweepPips * pip || g_watch[s].extreme > L + InpMaxSweepPips * pip)
                          : (c < L - InpMaxSweepPips * pip || g_watch[s].extreme < L - InpMaxSweepPips * pip);
      if(broken)
      {
         g_watch[s].active = false;
         MarkUsed(L);
         continue;
      }

      // Konfirmimi: mbyllje mbrapa nivelit dhe pertej struktures se vogel
      bool confirmed = d < 0 ? (c < L && c < LowestLow(2, InpMssBars)   && (!InpNeedBody || c < o))
                             : (c > L && c > HighestHigh(2, InpMssBars) && (!InpNeedBody || c > o));
      if(confirmed)
      {
         g_watch[s].active = false;
         MarkUsed(L);
         if(result == 0)
         {
            result       = d;
            g_sigLevel   = L;
            g_sigExtreme = g_watch[s].extreme;
         }
         else
            result = 2;                    // te dy anet njekohesisht: asnje hyrje
      }
   }
   return result == 2 ? 0 : result;
}

//+------------------------------------------------------------------+
void StartWatch(const int s, const int d, const double level, const double extreme)
{
   g_watch[s].active  = true;
   g_watch[s].dir     = d;
   g_watch[s].level   = level;
   g_watch[s].extreme = extreme;
   g_watch[s].start   = g_barNo;
}

//+------------------------------------------------------------------+
double LowestLow(const int from, const int count)
{
   double m = DBL_MAX;
   for(int i = from; i < from + count; i++)
   {
      double v = iLow(_Symbol, InpEntryTF, i);
      if(v > 0 && v < m) m = v;
   }
   return m;
}

//+------------------------------------------------------------------+
double HighestHigh(const int from, const int count)
{
   double m = 0;
   for(int i = from; i < from + count; i++)
      m = MathMax(m, iHigh(_Symbol, InpEntryTF, i));
   return m;
}

//+------------------------------------------------------------------+
//| SL pas bishtit, TP te niveli tjeter. 1 ose 2 pozicione.           |
//+------------------------------------------------------------------+
void OpenTrade(const int dir, const double extreme)
{
   double pip   = InpPipSize;
   double price = dir > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slPx  = extreme - dir * InpSLBufPips * pip;
   double risk  = MathMax(InpMinSLPips, dir * (price - slPx) / pip);
   if(risk > InpMaxSLPips)
   {
      PrintFormat("Hyrja u anulua: SL %.0f pips > %d", risk, InpMaxSLPips);
      return;
   }

   // Niveli kyc me i afert ne drejtim te tregtimit
   double nearest = 0;
   for(int i = 0; i < ArraySize(g_levels); i++)
   {
      double dist = dir * (g_levels[i] - price) / pip;
      if(dist <= InpZonePips) continue;
      if(nearest == 0 || dist < dir * (nearest - price) / pip)
         nearest = g_levels[i];
   }

   double target;
   if(nearest != 0)
   {
      target = nearest - dir * InpTPBufPips * pip;
      if(dir * (target - price) / pip < InpMinRR * risk)
      {
         PrintFormat("Hyrja u anulua: niveli tjeter %.2f eshte me afer se %.1fR", nearest, InpMinRR);
         return;
      }
   }
   else
      target = price + dir * InpFallbackRR * risk * pip;

   double rr   = dir * (target - price) / pip / risk;
   double lots = NormalizeLots(InpLots);
   // SELL mbyllet me cmimin Ask, ndersa grafiku tregon Bid. Pa kete, TP mund te preket ne grafik
   // por te mos mbyllet, sepse Ask eshte ende spread-in me lart.
   double adj  = (dir < 0 && InpSellSpreadAdj) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID) : 0;
   double sl   = NormalizeDouble(price - dir * risk * pip + adj, _Digits);
   double tp   = NormalizeDouble(target + adj, _Digits);
   string tag  = dir > 0 ? "BUY LVL" : "SELL LVL";

   if(rr >= InpTwoPosRR)
   {
      double tp1 = NormalizeDouble(price + dir * InpTP1R * risk * pip + adj, _Digits);
      if(!SendOrder(dir, lots, sl, tp1, tag + " TP1")) return;
      SendOrder(dir, lots, sl, tp, tag + " TP2");
   }
   else
      SendOrder(dir, lots, sl, tp, tag + " TP");

   PrintFormat("%s te %.2f | SL %.0f pips | objektivi %.2f (%.1fR) | %d pozicion(e)",
               tag, g_sigLevel, risk, target, rr, rr >= InpTwoPosRR ? 2 : 1);
}

//+------------------------------------------------------------------+
bool SendOrder(const int dir, const double lots, const double sl, const double tp, const string cmt)
{
   bool ok = dir > 0 ? trade.Buy(lots, _Symbol, 0, sl, tp, cmt) : trade.Sell(lots, _Symbol, 0, sl, tp, cmt);
   if(!ok)
      Print(cmt, " deshtoi: ", trade.ResultRetcodeDescription());
   return ok;
}

//+------------------------------------------------------------------+
//| Kur mbetet vetem pozicioni TP2 (TP1 u mor), SL kalon ne hyrje     |
//+------------------------------------------------------------------+
void ManageBreakEven()
{
   if(!InpBreakEven || CountMyPositions() != 1)
      return;

   double pip     = InpPipSize;
   double minStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsMyPosition()) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), "TP2") < 0) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
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
//| Kufijte ditore: numri i hyrjeve dhe humbja e sotme                |
//+------------------------------------------------------------------+
bool AreDailyLimitsOk()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   t.hour = 0; t.min = 0; t.sec = 0;
   if(!HistorySelect(StructToTime(t), TimeCurrent() + 60))
      return true;

   double pl     = 0;
   int    setups = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != (long)InpMagic) continue;

      // Cdo hyrje ka nje pozicion pa "TP2" ne koment
      if(HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN
         && StringFind(HistoryDealGetString(deal, DEAL_COMMENT), "TP2") < 0)
         setups++;
      pl += HistoryDealGetDouble(deal, DEAL_PROFIT)
          + HistoryDealGetDouble(deal, DEAL_COMMISSION)
          + HistoryDealGetDouble(deal, DEAL_SWAP);
   }

   if(InpMaxTradesPerDay > 0 && setups >= InpMaxTradesPerDay) return false;
   if(InpDailyLossStop   > 0 && pl <= -InpDailyLossStop)      return false;
   return true;
}

//+------------------------------------------------------------------+
bool IsTradingHour()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   if(InpStartHour <= InpEndHour)
      return t.hour >= InpStartHour && t.hour < InpEndHour;
   return t.hour >= InpStartHour || t.hour < InpEndHour;
}

//+------------------------------------------------------------------+
bool IsSpreadOk()
{
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return spread / InpPipSize <= InpMaxSpreadPips;
}

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
//| Ne fund te testit (tab-i Journal): rezultati per BUY dhe SELL     |
//+------------------------------------------------------------------+
void PrintStats()
{
   if(!HistorySelect(0, TimeCurrent() + 60))
      return;

   string types[2] = {"BUY LVL", "SELL LVL"};
   int    setups[2] = {0, 0};
   int    cnt[2]    = {0, 0};
   int    won[2]    = {0, 0};
   double net[2]    = {0, 0};

   long posIds[];
   int  posType[];
   int  nPos  = 0;
   int  total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != (long)InpMagic) continue;

      long   posId = HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      double pl    = HistoryDealGetDouble(deal, DEAL_PROFIT)
                   + HistoryDealGetDouble(deal, DEAL_COMMISSION)
                   + HistoryDealGetDouble(deal, DEAL_SWAP);

      if(HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
      {
         string cmt = HistoryDealGetString(deal, DEAL_COMMENT);
         int t = StringFind(cmt, types[0]) == 0 ? 0 : StringFind(cmt, types[1]) == 0 ? 1 : -1;
         ArrayResize(posIds, nPos + 1, 1000);
         ArrayResize(posType, nPos + 1, 1000);
         posIds[nPos]  = posId;
         posType[nPos] = t;
         nPos++;
         if(t >= 0)
         {
            net[t] += pl;
            if(StringFind(cmt, "TP2") < 0) setups[t]++;
         }
         continue;
      }

      int t = -1;
      for(int k = nPos - 1; k >= 0; k--)
         if(posIds[k] == posId) { t = posType[k]; break; }
      if(t < 0) continue;
      cnt[t]++;
      if(pl > 0) won[t]++;
      net[t] += pl;
   }

   Print("===== KeyLevelXAU: rezultati (", _Symbol, ") =====");
   for(int k = 0; k < 2; k++)
   {
      double wr = cnt[k] > 0 ? 100.0 * won[k] / cnt[k] : 0.0;
      PrintFormat("%-8s : %4d hyrje | %4d pozicione | fitues %5.1f%% | neto %9.2f",
                  types[k], setups[k], cnt[k], wr, net[k]);
   }
}
//+------------------------------------------------------------------+
