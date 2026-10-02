//+------------------------------------------------------------------+
//|                                                DonchianMulti.mq5 |
//|  Runs up to three independent Donchian breakout systems on one   |
//|  chart, each on its own timeframe and channel length, each with  |
//|  its own position (magic = base + system index).                 |
//|  Per system:                                                     |
//|   - Entry: closed bar breaks the highest high / lowest low of the|
//|     previous N bars, in the direction of the 200 EMA.            |
//|   - Exit: initial stop k x ATR, chandelier trail k x ATR from the|
//|     extreme since entry, optional TP (R) and breakeven at BE x R.|
//|   - Volatility filter: trade only when ATR > ratio x its average.|
//|  Defaults: H1 channels 20/60/100, k 2 - positive in all 7 years  |
//|  of XAUUSD 2020-2026 in backtest (see backtest/RESULTS.md).      |
//+------------------------------------------------------------------+
#property copyright "Marko"
#property version   "2.00"

#include <Trade/Trade.mqh>

input group "System 1"
input bool            InpS1On  = true;        // System 1 enabled
input ENUM_TIMEFRAMES InpS1TF  = PERIOD_H1;   // System 1 timeframe
input int             InpS1N   = 20;          // System 1 channel (bars)
input double          InpS1K   = 2.0;         // System 1 stop/trail (ATR x)

input group "System 2"
input bool            InpS2On  = true;        // System 2 enabled
input ENUM_TIMEFRAMES InpS2TF  = PERIOD_H1;   // System 2 timeframe
input int             InpS2N   = 60;          // System 2 channel (bars)
input double          InpS2K   = 2.0;         // System 2 stop/trail (ATR x)

input group "System 3"
input bool            InpS3On  = true;        // System 3 enabled
input ENUM_TIMEFRAMES InpS3TF  = PERIOD_H1;   // System 3 timeframe
input int             InpS3N   = 100;         // System 3 channel (bars)
input double          InpS3K   = 2.0;         // System 3 stop/trail (ATR x)

input group "Take profit / Breakeven"
input double InpTPR     = 4.0;   // Take profit in R (0 = no TP, trail only)
input double InpBEAtR   = 1.0;   // Move SL to breakeven after this many R (0 = off)
input double InpBELockR = 0.1;   // Breakeven lock: SL = entry + this many R

input group "Volatility filter"
input bool   InpUseVolFilter = true;  // Trade only when ATR > ratio x its average
input int    InpVolLookbackH1 = 1440; // ATR average length in H1 bars (~60 trading days; scaled to each TF)
input double InpVolRatio     = 1.2;   // Min ATR / average ATR

input group "Common"
input bool   InpUseTrend        = true;  // Trade only with the trend EMA
input int    InpTrendEMA        = 200;   // Trend EMA period (on each system's timeframe)
input int    InpATRPeriod       = 14;    // ATR period
input double InpRiskPercent     = 0.25;  // Risk per trade, % of balance (each system)
input double InpFixedLot        = 0.0;   // Fixed lot per trade (0 = use risk %)
input int    InpMaxSpreadPoints = 60;    // Max spread in points (0 = off)
input double InpMaxDailyLossPct = 3.0;   // No new trades after this daily loss % (0 = off)

input group "Execution"
input ulong  InpMagicBase = 20261000;    // Magic base (system i uses base + i)
input int    InpSlippage  = 30;          // Max slippage in points
input string InpComment   = "DonMulti";

#define NSYS 3

struct Sys
{
   bool            on;
   ENUM_TIMEFRAMES tf;
   int             n;
   double          k;
   ulong           magic;
   int             hATR;
   int             hEMA;
   datetime        lastBar;
};

CTrade trade;
Sys    sys[NSYS];
double dayStartBalance = 0.0;
int    currentDay = -1;

//+------------------------------------------------------------------+
int OnInit()
{
   sys[0].on = InpS1On; sys[0].tf = InpS1TF; sys[0].n = InpS1N; sys[0].k = InpS1K;
   sys[1].on = InpS2On; sys[1].tf = InpS2TF; sys[1].n = InpS2N; sys[1].k = InpS2K;
   sys[2].on = InpS3On; sys[2].tf = InpS3TF; sys[2].n = InpS3N; sys[2].k = InpS3K;

   for(int i = 0; i < NSYS; i++)
   {
      sys[i].magic = InpMagicBase + i + 1;
      sys[i].lastBar = 0;
      sys[i].hATR = INVALID_HANDLE;
      sys[i].hEMA = INVALID_HANDLE;
      if(!sys[i].on)
         continue;
      if(sys[i].n < 2 || sys[i].k <= 0.0)
      {
         Print("System ", i + 1, ": channel must be >= 2 and ATR multiplier > 0.");
         return INIT_PARAMETERS_INCORRECT;
      }
      sys[i].hATR = iATR(_Symbol, sys[i].tf, InpATRPeriod);
      sys[i].hEMA = iMA(_Symbol, sys[i].tf, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(sys[i].hATR == INVALID_HANDLE || sys[i].hEMA == INVALID_HANDLE)
      {
         Print("System ", i + 1, ": failed to create indicator handles, error ", GetLastError());
         return INIT_FAILED;
      }
   }
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < NSYS; i++)
   {
      if(sys[i].hATR != INVALID_HANDLE) IndicatorRelease(sys[i].hATR);
      if(sys[i].hEMA != INVALID_HANDLE) IndicatorRelease(sys[i].hEMA);
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   for(int i = 0; i < NSYS; i++)
      if(sys[i].on)
         RunSystem(sys[i]);
}

//+------------------------------------------------------------------+
// One system: works once per closed bar of its own timeframe.
void RunSystem(Sys &s)
{
   datetime barTime = iTime(_Symbol, s.tf, 0);
   if(barTime == 0 || barTime == s.lastBar)
      return;

   double atr[], ema[];
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(ema, true);
   if(CopyBuffer(s.hATR, 0, 0, 2, atr) != 2 || CopyBuffer(s.hEMA, 0, 0, 2, ema) != 2)
      return; // data not ready; retry next tick
   if(Bars(_Symbol, s.tf) < s.n + 3)
      return;
   s.lastBar = barTime;

   ulong ticket = FindPosition(s.magic);
   if(ticket != 0)
   {
      TrailStop(s, ticket, atr[1]);
      return;
   }

   double close1 = iClose(_Symbol, s.tf, 1);
   int hiIdx = iHighest(_Symbol, s.tf, MODE_HIGH, s.n, 2);
   int loIdx = iLowest(_Symbol, s.tf, MODE_LOW, s.n, 2);
   if(hiIdx < 0 || loIdx < 0)
      return;
   double chHigh = iHigh(_Symbol, s.tf, hiIdx);
   double chLow  = iLow(_Symbol, s.tf, loIdx);

   int dir = 0;
   if(close1 > chHigh && (!InpUseTrend || close1 > ema[1])) dir = 1;
   else if(close1 < chLow && (!InpUseTrend || close1 < ema[1])) dir = -1;
   if(dir == 0 || !VolatilityOK(s, atr[1]) || !TradingAllowed())
      return;

   OpenTrade(s, dir, s.k * atr[1]);
}

//+------------------------------------------------------------------+
void OpenTrade(const Sys &s, const int dir, const double slDist)
{
   int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double price   = dir == 1 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double dist    = MathMax(slDist, minStop);
   double sl      = NormalizeDouble(price - dir * dist, digits);
   double tp      = InpTPR > 0.0 ? NormalizeDouble(price + dir * dist * InpTPR, digits) : 0.0;

   double lots = NormalizeLots(InpFixedLot > 0.0 ? InpFixedLot : LotsForRisk(dist));
   if(lots <= 0.0)
   {
      Print("Lot size below broker minimum for this risk, signal skipped.");
      return;
   }
   trade.SetExpertMagicNumber(s.magic);
   string comment = InpComment + " " + EnumToString(s.tf) + " N" + IntegerToString(s.n);
   bool ok = dir == 1 ? trade.Buy(lots, _Symbol, price, sl, tp, comment)
                      : trade.Sell(lots, _Symbol, price, sl, tp, comment);
   if(!ok)
      Print("Order failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
// Chandelier stop on the system's own timeframe, only ever tightened.
void TrailStop(const Sys &s, const ulong ticket, const double atr)
{
   if(!PositionSelectByTicket(ticket))
      return;
   int      digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double   point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double   minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   datetime opened  = (datetime)PositionGetInteger(POSITION_TIME);
   double   sl      = PositionGetDouble(POSITION_SL);
   double   tp      = PositionGetDouble(POSITION_TP);
   bool     isBuy   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;

   int count = iBarShift(_Symbol, s.tf, opened); // closed bars 1..count since entry
   if(count < 1)
      return;

   // Initial risk (1R) = k x ATR of the signal bar, the bar before the entry bar
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double risk = 0.0;
   double atrEntry[];
   if(CopyBuffer(s.hATR, 0, count + 1, 1, atrEntry) == 1)
      risk = s.k * atrEntry[0];

   trade.SetExpertMagicNumber(s.magic);
   if(isBuy)
   {
      double ext = iHigh(_Symbol, s.tf, iHighest(_Symbol, s.tf, MODE_HIGH, count, 1));
      double newSL = NormalizeDouble(ext - s.k * atr, digits);
      if(InpBEAtR > 0.0 && risk > 0.0 && ext - open >= InpBEAtR * risk)
         newSL = MathMax(newSL, NormalizeDouble(open + InpBELockR * risk, digits));
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(newSL > sl + point && bid - newSL > minStop)
         trade.PositionModify(ticket, newSL, tp);
   }
   else
   {
      double ext = iLow(_Symbol, s.tf, iLowest(_Symbol, s.tf, MODE_LOW, count, 1));
      double newSL = NormalizeDouble(ext + s.k * atr, digits);
      if(InpBEAtR > 0.0 && risk > 0.0 && open - ext >= InpBEAtR * risk)
         newSL = MathMin(newSL, NormalizeDouble(open - InpBELockR * risk, digits));
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if((sl == 0.0 || newSL < sl - point) && newSL - ask > minStop)
         trade.PositionModify(ticket, newSL, tp);
   }
}

//+------------------------------------------------------------------+
// True when the signal bar's ATR is at least InpVolRatio x its average
// over ~InpVolLookbackH1 hours, measured on the system's own timeframe.
bool VolatilityOK(const Sys &s, const double atrNow)
{
   if(!InpUseVolFilter)
      return true;
   int bars = (int)MathMax(50, (double)InpVolLookbackH1 * PeriodSeconds(PERIOD_H1) / PeriodSeconds(s.tf));
   double hist[];
   int got = CopyBuffer(s.hATR, 0, 1, bars, hist);
   if(got < bars / 2)
      return false; // not enough history yet
   double sum = 0.0;
   for(int i = 0; i < got; i++) sum += hist[i];
   double avg = sum / got;
   return avg > 0.0 && atrNow >= InpVolRatio * avg;
}

//+------------------------------------------------------------------+
bool TradingAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;
   if(InpMaxSpreadPoints > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints)
   {
      Print("Spread too high, signal skipped.");
      return false;
   }
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   if(now.day_of_year != currentDay)
   {
      currentDay = now.day_of_year;
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   if(InpMaxDailyLossPct > 0.0 && dayStartBalance > 0.0)
   {
      double lossPct = (dayStartBalance - AccountInfoDouble(ACCOUNT_EQUITY)) / dayStartBalance * 100.0;
      if(lossPct >= InpMaxDailyLossPct)
      {
         Print("Daily loss limit reached (", DoubleToString(lossPct, 2), "%), no new trades today.");
         return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
ulong FindPosition(const ulong magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == magic)
         return ticket;
   }
   return 0;
}

//+------------------------------------------------------------------+
double LotsForRisk(const double slDistance)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0.0)
      tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0 || slDistance <= 0.0)
      return 0.0;
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   return riskMoney / (slDistance / tickSize * tickValue);
}

//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0)
      return 0.0;
   lots = MathFloor(lots / stepLot + 1e-9) * stepLot;
   if(lots < minLot)
      return 0.0; // never round up past the intended risk
   lots = MathMin(lots, maxLot);
   int stepDigits = (int)MathMax(0, MathCeil(-MathLog10(stepLot)));
   return NormalizeDouble(lots, stepDigits);
}
//+------------------------------------------------------------------+
