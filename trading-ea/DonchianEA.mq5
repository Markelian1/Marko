//+------------------------------------------------------------------+
//|                                                   DonchianEA.mq5 |
//|  Donchian channel breakout with a chandelier ATR trailing stop.  |
//|  - Entry: H1 close breaks the highest high / lowest low of the   |
//|    previous N bars, in the direction of the 200 EMA.             |
//|  - Exit: no fixed TP. Initial stop k x ATR; then the stop trails |
//|    the highest high (lowest low) since entry by k x ATR.         |
//|  Designed to run next to TrendEA_Pro (different magic number).   |
//|  Defaults = centre of the robust region on XAUUSD H1 (backtest/).|
//+------------------------------------------------------------------+
#property copyright "Marko"
#property version   "1.00"

#include <Trade/Trade.mqh>

input group "Strategy"
input ENUM_TIMEFRAMES InpTF        = PERIOD_H1; // Signal timeframe
input int             InpChannel   = 40;        // Donchian channel length (bars)
input bool            InpUseTrend  = true;      // Trade only with the trend EMA
input int             InpTrendEMA  = 200;       // Trend EMA period
input int             InpATRPeriod = 14;        // ATR period
input double          InpATRMult   = 3.0;       // Initial stop and trailing distance (ATR x)

input group "Risk"
input double InpRiskPercent     = 0.5;  // Risk per trade, % of balance
input double InpFixedLot        = 0.0;  // Fixed lot (0 = use risk %)
input int    InpMaxSpreadPoints = 60;   // Max spread in points (0 = off)
input double InpMaxDailyLossPct = 3.0;  // No new trades after this daily loss % (0 = off)

input group "Execution"
input ulong  InpMagic    = 20260930;    // Magic number (keep different from TrendEA_Pro)
input int    InpSlippage = 30;          // Max slippage in points
input string InpComment  = "Donchian";

CTrade   trade;
int      hATR = INVALID_HANDLE;
int      hEMA = INVALID_HANDLE;
datetime lastBarTime = 0;
double   dayStartBalance = 0.0;
int      currentDay = -1;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpChannel < 2 || InpATRMult <= 0.0)
   {
      Print("Channel must be >= 2 and ATR multiplier > 0.");
      return INIT_PARAMETERS_INCORRECT;
   }
   hATR = iATR(_Symbol, InpTF, InpATRPeriod);
   hEMA = iMA(_Symbol, InpTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hATR == INVALID_HANDLE || hEMA == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles, error ", GetLastError());
      return INIT_FAILED;
   }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(hATR);
   IndicatorRelease(hEMA);
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Work once per closed bar, like the backtest
   datetime barTime = iTime(_Symbol, InpTF, 0);
   if(barTime == 0 || barTime == lastBarTime)
      return;

   double atr[], ema[];
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(ema, true);
   if(CopyBuffer(hATR, 0, 0, 2, atr) != 2 || CopyBuffer(hEMA, 0, 0, 2, ema) != 2)
      return; // data not ready; retry next tick
   if(Bars(_Symbol, InpTF) < InpChannel + 3)
      return;
   lastBarTime = barTime;

   ulong ticket = OurPosition();
   if(ticket != 0)
   {
      TrailStop(ticket, atr[1]);
      return;
   }

   double close1 = iClose(_Symbol, InpTF, 1);
   // Channel of the N bars before the signal bar (bars 2 .. N+1)
   int hiIdx = iHighest(_Symbol, InpTF, MODE_HIGH, InpChannel, 2);
   int loIdx = iLowest(_Symbol, InpTF, MODE_LOW, InpChannel, 2);
   if(hiIdx < 0 || loIdx < 0)
      return;
   double chHigh = iHigh(_Symbol, InpTF, hiIdx);
   double chLow  = iLow(_Symbol, InpTF, loIdx);

   int dir = 0;
   if(close1 > chHigh && (!InpUseTrend || close1 > ema[1])) dir = 1;
   else if(close1 < chLow && (!InpUseTrend || close1 < ema[1])) dir = -1;
   if(dir == 0 || !TradingAllowed())
      return;

   OpenTrade(dir, InpATRMult * atr[1]);
}

//+------------------------------------------------------------------+
void OpenTrade(const int dir, const double slDist)
{
   int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double price   = dir == 1 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double dist    = MathMax(slDist, minStop);
   double sl      = NormalizeDouble(price - dir * dist, digits);

   double lots = InpFixedLot > 0.0 ? InpFixedLot : LotsForRisk(dist);
   lots = NormalizeLots(lots);
   if(lots <= 0.0)
   {
      Print("Lot size below broker minimum for this risk, signal skipped.");
      return;
   }
   bool ok = dir == 1 ? trade.Buy(lots, _Symbol, price, sl, 0.0, InpComment)
                      : trade.Sell(lots, _Symbol, price, sl, 0.0, InpComment);
   if(!ok)
      Print("Order failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
// Chandelier stop: extreme since entry -/+ k x ATR, only ever tightened.
void TrailStop(const ulong ticket, const double atr)
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

   // Closed bars since entry (bar 1 back to the bar the trade opened in)
   int openShift = iBarShift(_Symbol, InpTF, opened);
   int count = openShift; // bars 1..openShift
   if(count < 1)
      return;

   if(isBuy)
   {
      double ext = iHigh(_Symbol, InpTF, iHighest(_Symbol, InpTF, MODE_HIGH, count, 1));
      double newSL = NormalizeDouble(ext - InpATRMult * atr, digits);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(newSL > sl + point && bid - newSL > minStop)
         trade.PositionModify(ticket, newSL, tp);
   }
   else
   {
      double ext = iLow(_Symbol, InpTF, iLowest(_Symbol, InpTF, MODE_LOW, count, 1));
      double newSL = NormalizeDouble(ext + InpATRMult * atr, digits);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if((sl == 0.0 || newSL < sl - point) && newSL - ask > minStop)
         trade.PositionModify(ticket, newSL, tp);
   }
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
ulong OurPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
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
