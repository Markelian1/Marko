//+------------------------------------------------------------------+
//|                                             TrendScalperXAU.mq5  |
//|  Scalper për XAUUSD që ndjek trendin.                            |
//|  - Trendi: EMA e shpejtë / e ngadaltë në M15                      |
//|  - Hyrja: pullback te EMA20 në M5 dhe mbyllje në drejtim trendi  |
//|  - Hap 2 pozicione: TP1 (20 pips) dhe TP2 (50 pips)              |
//|  - Pas TP1, SL e pozicionit të dytë kalon në break-even          |
//|  - Lot fiks, PA martingale                                        |
//+------------------------------------------------------------------+
#property copyright "Marko"
#property version   "1.00"
#property description "Scalper per ar qe ndjek trendin, TP1 20 pips / TP2 50 pips, pa martingale."

#include <Trade\Trade.mqh>

input group "Madhesia e pozicionit"
input double InpLots            = 0.01;   // Loti per secilin nga 2 pozicionet
input double InpPipSize         = 0.10;   // 1 pip ne ar = 0.10$ levizje cmimi

input group "TP / SL (ne pips)"
input int    InpTP1Pips         = 20;     // TP i pozicionit 1
input int    InpTP2Pips         = 50;     // TP i pozicionit 2
input int    InpSLPips          = 30;     // SL per te dy pozicionet
input bool   InpBreakEven       = true;   // Pas TP1, SL e pozicionit 2 ne hyrje
input int    InpBEOffsetPips    = 1;      // Sa pips mbi hyrje (mbulon komisionin)

input group "Filtri i trendit"
input ENUM_TIMEFRAMES InpTrendTF      = PERIOD_M15;
input int    InpTrendFastEMA    = 50;
input int    InpTrendSlowEMA    = 200;

input group "Sinjali i hyrjes"
input ENUM_TIMEFRAMES InpEntryTF      = PERIOD_M5;
input int    InpEntryEMA        = 20;

input group "Kufizime"
input int    InpMaxSpreadPips   = 4;      // Mos hyj nese spread-i eshte me i madh
input int    InpStartHour       = 3;      // Ora e serverit kur fillon
input int    InpEndHour         = 21;     // Ora e serverit kur ndalon hyrjet e reja
input double InpDailyProfitStop = 0;      // Ndalo per sot pas ketij fitimi (0 = pa limit)
input double InpDailyLossStop   = 12;     // Ndalo per sot pas kesaj humbjeje (0 = pa limit)
input int    InpMaxSetupsPerDay = 10;     // Sa hyrje (me nga 2 pozicione) ne dite
input ulong  InpMagic           = 20260923;

CTrade   trade;
int      hTrendFast = INVALID_HANDLE;
int      hTrendSlow = INVALID_HANDLE;
int      hEntryEMA  = INVALID_HANDLE;
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpTP1Pips <= 0 || InpTP2Pips <= InpTP1Pips || InpSLPips <= 0 || InpPipSize <= 0)
   {
      Print("Parametra te gabuar: duhet TP2 > TP1 > 0, SL > 0 dhe PipSize > 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   hTrendFast = iMA(_Symbol, InpTrendTF, InpTrendFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hTrendSlow = iMA(_Symbol, InpTrendTF, InpTrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEntryEMA  = iMA(_Symbol, InpEntryTF, InpEntryEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hTrendFast == INVALID_HANDLE || hTrendSlow == INVALID_HANDLE || hEntryEMA == INVALID_HANDLE)
   {
      Print("Nuk u krijuan indikatoret EMA");
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
   if(hTrendFast != INVALID_HANDLE) IndicatorRelease(hTrendFast);
   if(hTrendSlow != INVALID_HANDLE) IndicatorRelease(hTrendSlow);
   if(hEntryEMA  != INVALID_HANDLE) IndicatorRelease(hEntryEMA);
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageBreakEven();

   // Sinjalet kontrollohen vetem kur hapet nje qiri i ri ne M5
   datetime barTime = iTime(_Symbol, InpEntryTF, 0);
   if(barTime == 0 || barTime == g_lastBarTime)
      return;
   g_lastBarTime = barTime;

   if(CountMyPositions() > 0) return;   // nje hyrje ne te njejten kohe
   if(!IsTradingHour())       return;
   if(!IsSpreadOk())          return;
   if(!AreDailyLimitsOk())    return;

   int trend = GetTrend();
   if(trend == 0) return;

   int signal = GetEntrySignal(trend);
   if(signal != 0)
      OpenSetup(signal);
}

//+------------------------------------------------------------------+
//| +1 = trend lart, -1 = trend poshte, 0 = pa trend te qarte         |
//+------------------------------------------------------------------+
int GetTrend()
{
   double fast[1], slow[1];
   if(CopyBuffer(hTrendFast, 0, 1, 1, fast) != 1) return 0;
   if(CopyBuffer(hTrendSlow, 0, 1, 1, slow) != 1) return 0;

   double close = iClose(_Symbol, InpTrendTF, 1);
   if(close == 0) return 0;

   if(fast[0] > slow[0] && close > fast[0]) return  1;
   if(fast[0] < slow[0] && close < fast[0]) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Pullback: qiriri i fundit preku EMA20 dhe u mbyll ne drejtim te   |
//| trendit (buy: qiri jeshil mbi EMA, sell: qiri i kuq nen EMA).     |
//+------------------------------------------------------------------+
int GetEntrySignal(const int trend)
{
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
//| Hap 2 pozicione me te njejtin SL: njeri me TP1, tjetri me TP2     |
//+------------------------------------------------------------------+
void OpenSetup(const int dir)
{
   double lots = NormalizeLots(InpLots);
   double pip  = InpPipSize;

   if(dir > 0)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = NormalizeDouble(price - InpSLPips  * pip, _Digits);
      double tp1 = NormalizeDouble(price + InpTP1Pips * pip, _Digits);
      double tp2 = NormalizeDouble(price + InpTP2Pips * pip, _Digits);

      if(!trade.Buy(lots, _Symbol, 0, sl, tp1, "TP1"))
      {
         Print("Buy TP1 deshtoi: ", trade.ResultRetcodeDescription());
         return;   // pa TP1 nuk hapim as TP2
      }
      if(!trade.Buy(lots, _Symbol, 0, sl, tp2, "TP2"))
         Print("Buy TP2 deshtoi: ", trade.ResultRetcodeDescription());
   }
   else
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = NormalizeDouble(price + InpSLPips  * pip, _Digits);
      double tp1 = NormalizeDouble(price - InpTP1Pips * pip, _Digits);
      double tp2 = NormalizeDouble(price - InpTP2Pips * pip, _Digits);

      if(!trade.Sell(lots, _Symbol, 0, sl, tp1, "TP1"))
      {
         Print("Sell TP1 deshtoi: ", trade.ResultRetcodeDescription());
         return;
      }
      if(!trade.Sell(lots, _Symbol, 0, sl, tp2, "TP2"))
         Print("Sell TP2 deshtoi: ", trade.ResultRetcodeDescription());
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
