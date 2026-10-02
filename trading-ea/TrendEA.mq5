//+------------------------------------------------------------------+
//|                                                      TrendEA.mq5 |
//|  EMA crossover trend-following Expert Advisor for MetaTrader 5.  |
//|  - Entry: fast EMA crosses slow EMA, confirmed by RSI filter     |
//|  - Exits: ATR-based stop loss / take profit, optional trailing   |
//|  - Sizing: fixed lot or % of balance risked per trade            |
//+------------------------------------------------------------------+
#property copyright "Marko"
#property version   "1.00"

#include <Trade/Trade.mqh>

//--- Strategy
input group "Strategy"
input ENUM_TIMEFRAMES InpTimeframe    = PERIOD_H1; // Signal timeframe
input int             InpFastEMA      = 20;        // Fast EMA period
input int             InpSlowEMA      = 50;        // Slow EMA period
input int             InpRSIPeriod    = 14;        // RSI period
input double          InpRSIBuyMin    = 50.0;      // Buy only if RSI above
input double          InpRSISellMax   = 50.0;      // Sell only if RSI below
input bool            InpCloseOnOpposite = true;   // Close position on opposite signal

//--- Risk management
input group "Risk"
input bool   InpUseRiskPercent = true;  // Size by % risk (false = fixed lot)
input double InpRiskPercent    = 1.0;   // Risk per trade, % of balance
input double InpFixedLot       = 0.10;  // Fixed lot size
input int    InpATRPeriod      = 14;    // ATR period
input double InpSLATRMult      = 2.0;   // Stop loss = ATR x
input double InpTPATRMult      = 3.0;   // Take profit = ATR x (0 = none)
input bool   InpUseTrailing    = true;  // Enable ATR trailing stop
input double InpTrailATRMult   = 1.5;   // Trailing distance = ATR x

//--- Filters
input group "Filters"
input int    InpMaxSpreadPoints = 30;   // Max spread in points (0 = off)
input int    InpStartHour       = 0;    // Trading start hour (server time)
input int    InpEndHour         = 24;   // Trading end hour (server time)
input double InpMaxDailyLossPct = 5.0;  // Stop for the day after this % loss (0 = off)

//--- Execution
input group "Execution"
input ulong  InpMagic     = 20260923;   // Magic number
input int    InpSlippage  = 10;         // Max slippage in points
input string InpComment   = "TrendEA";  // Order comment

CTrade   trade;
int      hFast = INVALID_HANDLE;
int      hSlow = INVALID_HANDLE;
int      hRSI  = INVALID_HANDLE;
int      hATR  = INVALID_HANDLE;
datetime lastBarTime = 0;
double   dayStartBalance = 0.0;
int      currentDay = -1;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpFastEMA <= 0 || InpSlowEMA <= 0 || InpFastEMA >= InpSlowEMA)
   {
      Print("Invalid EMA periods: fast must be > 0 and less than slow.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSLATRMult <= 0.0)
   {
      Print("Stop loss ATR multiplier must be > 0.");
      return INIT_PARAMETERS_INCORRECT;
   }

   hFast = iMA(_Symbol, InpTimeframe, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(_Symbol, InpTimeframe, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI  = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   hATR  = iATR(_Symbol, InpTimeframe, InpATRPeriod);
   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE ||
      hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE)
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
   if(hFast != INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow != INVALID_HANDLE) IndicatorRelease(hSlow);
   if(hRSI  != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hATR  != INVALID_HANDLE) IndicatorRelease(hATR);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(InpUseTrailing)
      ManageTrailingStop();

   // Evaluate signals once per closed bar
   datetime barTime = iTime(_Symbol, InpTimeframe, 0);
   if(barTime == 0 || barTime == lastBarTime)
      return;

   double fast[], slow[], rsi[], atr[];
   // Index 1 = last closed bar, index 2 = the bar before it
   if(!CopyValues(hFast, fast, 3) || !CopyValues(hSlow, slow, 3) ||
      !CopyValues(hRSI, rsi, 2)   || !CopyValues(hATR, atr, 2))
      return; // data not ready yet; retry next tick

   lastBarTime = barTime;

   bool crossUp   = fast[2] <= slow[2] && fast[1] > slow[1];
   bool crossDown = fast[2] >= slow[2] && fast[1] < slow[1];
   bool buySignal  = crossUp   && rsi[1] > InpRSIBuyMin;
   bool sellSignal = crossDown && rsi[1] < InpRSISellMax;

   if(InpCloseOnOpposite)
   {
      if(crossUp)   ClosePositions(POSITION_TYPE_SELL);
      if(crossDown) ClosePositions(POSITION_TYPE_BUY);
   }

   if(!buySignal && !sellSignal)
      return;
   if(HasOpenPosition())
      return;
   if(!TradingAllowed())
      return;

   OpenTrade(buySignal ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, atr[1]);
}

//+------------------------------------------------------------------+
bool CopyValues(const int handle, double &buffer[], const int count)
{
   ArraySetAsSeries(buffer, true);
   return CopyBuffer(handle, 0, 0, count, buffer) == count;
}

//+------------------------------------------------------------------+
bool TradingAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   if(now.hour < InpStartHour || now.hour >= InpEndHour)
      return false;

   if(InpMaxSpreadPoints > 0 &&
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints)
   {
      Print("Spread too high, skipping signal.");
      return false;
   }

   // Daily loss guard
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
void OpenTrade(const ENUM_ORDER_TYPE type, const double atrValue)
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double price  = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDist = atrValue * InpSLATRMult;
   double tpDist = atrValue * InpTPATRMult;

   // Respect broker minimum stop distance
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   slDist = MathMax(slDist, minStop);
   if(InpTPATRMult > 0.0)
      tpDist = MathMax(tpDist, minStop);

   double sl, tp = 0.0;
   if(type == ORDER_TYPE_BUY)
   {
      sl = price - slDist;
      if(InpTPATRMult > 0.0) tp = price + tpDist;
   }
   else
   {
      sl = price + slDist;
      if(InpTPATRMult > 0.0) tp = price - tpDist;
   }
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   double lots = InpUseRiskPercent ? LotsForRisk(slDist) : InpFixedLot;
   lots = NormalizeLots(lots);
   if(lots <= 0.0)
   {
      Print("Calculated lot size is zero, trade skipped.");
      return;
   }

   bool ok = (type == ORDER_TYPE_BUY)
             ? trade.Buy(lots, _Symbol, price, sl, tp, InpComment)
             : trade.Sell(lots, _Symbol, price, sl, tp, InpComment);
   if(!ok)
      Print("Order failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
// Lot size such that hitting the stop loses InpRiskPercent of balance
double LotsForRisk(const double slDistance)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0.0)
      tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0 || slDistance <= 0.0)
      return 0.0;

   double riskMoney   = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   double lossPerLot  = slDistance / tickSize * tickValue;
   return riskMoney / lossPerLot;
}

//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0)
      return 0.0;

   lots = MathFloor(lots / stepLot) * stepLot;
   if(lots < minLot)
      return 0.0; // risk too small for the minimum lot; don't over-risk
   lots = MathMin(lots, maxLot);

   int stepDigits = (int)MathMax(0, MathCeil(-MathLog10(stepLot)));
   return NormalizeDouble(lots, stepDigits);
}

//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void ClosePositions(const ENUM_POSITION_TYPE type)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic ||
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;
      if(!trade.PositionClose(ticket))
         Print("Close failed for #", ticket, ": ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   double atr[];
   if(!CopyValues(hATR, atr, 2))
      return;

   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minStop  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double trailDist = MathMax(atr[1] * InpTrailATRMult, minStop);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL     = PositionGetDouble(POSITION_SL);
      double curTP     = PositionGetDouble(POSITION_TP);

      if(type == POSITION_TYPE_BUY)
      {
         double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = NormalizeDouble(bid - trailDist, digits);
         // Only trail once in profit, and only move the stop forward
         if(bid - openPrice > trailDist && (curSL == 0.0 || newSL > curSL + point))
            trade.PositionModify(ticket, newSL, curTP);
      }
      else
      {
         double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = NormalizeDouble(ask + trailDist, digits);
         if(openPrice - ask > trailDist && (curSL == 0.0 || newSL < curSL - point))
            trade.PositionModify(ticket, newSL, curTP);
      }
   }
}
//+------------------------------------------------------------------+
