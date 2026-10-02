//+------------------------------------------------------------------+
//|                                                  TrendEA_Pro.mq5 |
//|  Trend-pullback Expert Advisor for MetaTrader 5 (same logic as   |
//|  the TradingView "TrendEA Pro" scripts). A trade opens only when |
//|  ALL of these agree on the last closed bar:                      |
//|   1. EMA stack in trend order (fast > slow > trend EMA for buys) |
//|   2. H1 and H4 closes vs their EMA 50 agree (last closed bars)   |
//|   3. ADX (Wilder) >= min and DI+/DI- agree with the direction    |
//|   4. Price pulled back to the fast EMA, closes held the slow EMA |
//|   5. Confirmation candle closes beyond the previous bar          |
//|   6. RSI in range, ATR not dead, inside the session              |
//|  Exits: two half positions - TP1 (1R) and TP2 (3R); the TP2 leg  |
//|  moves to breakeven once price reaches TP1. SL beyond the swing. |
//|  Defaults = settings validated on XAUUSD M15 (see backtest/).    |
//+------------------------------------------------------------------+
#property copyright "Marko"
#property version   "2.10"

#include <Trade/Trade.mqh>

input group "Timeframes"
input ENUM_TIMEFRAMES InpTF       = PERIOD_M15; // Signal timeframe
input bool            InpUseHTF   = true;       // Higher-timeframe filter
input ENUM_TIMEFRAMES InpHTF      = PERIOD_H1;  // HTF timeframe
input int             InpHTFEMA   = 50;         // HTF EMA period
input bool            InpUseHTF2  = true;       // Second higher-timeframe filter
input ENUM_TIMEFRAMES InpHTF2     = PERIOD_H4;  // HTF2 timeframe (same EMA period)

input group "Trend"
input int InpFastEMA = 21;   // Fast EMA
input int InpSlowEMA = 50;   // Slow EMA
input int InpBaseEMA = 200;  // Trend EMA

input group "Signal quality"
input bool   InpUseADX     = true;  // ADX trend-strength filter
input int    InpADXPeriod  = 14;    // ADX period
input double InpADXMin     = 20.0;  // Min ADX
input int    InpRSIPeriod  = 14;    // RSI period
input double InpRSIMaxLong = 70.0;  // Max RSI for buys
input double InpRSIMinShort= 30.0;  // Min RSI for sells
input int    InpPullback   = 5;     // Pullback lookback (bars)
input bool   InpUseVol     = true;  // Volatility filter
input double InpVolRatio   = 0.8;   // Min ATR vs its 50-bar average
input int    InpCooldown   = 10;    // Min bars between signals

input group "Risk"
input double InpRiskPercent = 1.0;  // Risk per trade, % of balance
input double InpFixedLot    = 0.0;  // Fixed total lot (0 = use risk %)
input int    InpATRPeriod   = 14;   // ATR period
input int    InpSwing       = 5;    // Swing lookback for SL (bars)
input double InpSLBuffer    = 0.8;  // SL buffer (ATR x)
input double InpMinSL       = 0.5;  // Min SL distance (ATR x)
input double InpMaxSL       = 3.0;  // Max SL distance (ATR x) - skip if wider
input double InpTP1R        = 1.0;  // TP1 (R multiple, half position)
input double InpTP2R        = 3.0;  // TP2 (R multiple, other half)
input bool   InpMoveBE      = true; // Move TP2 leg to breakeven at TP1

input group "Filters"
input bool   InpUseSession      = true; // Only trade inside session
input int    InpSessionStart    = 15;   // Session start hour (SERVER time)
input int    InpSessionEnd      = 23;   // Session end hour (SERVER time)
input int    InpMaxSpreadPoints = 50;   // Max spread in points (0 = off)
input double InpMaxDailyLossPct = 3.0;  // No new trades after this daily loss % (0 = off)

input group "Execution"
input ulong  InpMagic    = 20260924;     // Magic number (TP2 leg uses Magic+1)
input int    InpSlippage = 20;           // Max slippage in points
input string InpComment  = "TrendEA Pro";

CTrade   trade;
int      hFast, hSlow, hBase, hATR, hRSI, hADX, hHTF, hHTF2;
datetime lastBarTime = 0;
datetime lastSignalTime = 0;
double   dayStartBalance = 0.0;
int      currentDay = -1;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpFastEMA >= InpSlowEMA || InpSlowEMA >= InpBaseEMA)
   {
      Print("EMA periods must satisfy fast < slow < trend.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpTP1R <= 0.0 || InpTP2R < InpTP1R)
   {
      Print("TP multiples must satisfy 0 < TP1 <= TP2.");
      return INIT_PARAMETERS_INCORRECT;
   }

   hFast = iMA(_Symbol, InpTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(_Symbol, InpTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hBase = iMA(_Symbol, InpTF, InpBaseEMA, 0, MODE_EMA, PRICE_CLOSE);
   hATR  = iATR(_Symbol, InpTF, InpATRPeriod);
   hRSI  = iRSI(_Symbol, InpTF, InpRSIPeriod, PRICE_CLOSE);
   hADX  = iADXWilder(_Symbol, InpTF, InpADXPeriod);
   hHTF  = iMA(_Symbol, InpHTF, InpHTFEMA, 0, MODE_EMA, PRICE_CLOSE);
   hHTF2 = iMA(_Symbol, InpHTF2, InpHTFEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hHTF2 == INVALID_HANDLE ||
      hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE || hBase == INVALID_HANDLE ||
      hATR == INVALID_HANDLE || hRSI == INVALID_HANDLE || hADX == INVALID_HANDLE || hHTF == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles, error ", GetLastError());
      return INIT_FAILED;
   }

   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(hFast);
   IndicatorRelease(hSlow);
   IndicatorRelease(hBase);
   IndicatorRelease(hATR);
   IndicatorRelease(hRSI);
   IndicatorRelease(hADX);
   IndicatorRelease(hHTF);
   IndicatorRelease(hHTF2);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(InpMoveBE)
      ManageBreakeven();

   datetime barTime = iTime(_Symbol, InpTF, 0);
   if(barTime == 0 || barTime == lastBarTime)
      return;

   int dir = 0;
   double sl = 0.0;
   if(!EvaluateSignal(dir, sl))
      return; // data not ready; retry next tick
   lastBarTime = barTime;

   if(dir == 0 || HasOpenPosition())
      return;
   if(lastSignalTime > 0 && iBarShift(_Symbol, InpTF, lastSignalTime) - 1 < InpCooldown)
      return;
   if(!TradingAllowed())
      return;

   if(OpenTrade(dir, sl))
      lastSignalTime = iTime(_Symbol, InpTF, 1);
}

//+------------------------------------------------------------------+
bool Copy(const int handle, const int buffer, const int count, double &out[])
{
   ArraySetAsSeries(out, true);
   return CopyBuffer(handle, buffer, 0, count, out) == count;
}

//+------------------------------------------------------------------+
// Evaluates the last closed bar (index 1). Returns false if data is not ready.
// dir = 1 buy, -1 sell, 0 none; sl = stop level for that direction.
bool EvaluateSignal(int &dir, double &sl)
{
   dir = 0;
   int need = MathMax(MathMax(InpPullback, InpSwing), 2) + 2;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpTF, 0, need, r) != need)
      return false;

   double fast[], slow[], base[], atr[], rsi[], adx[], dip[], dim[];
   if(!Copy(hFast, 0, 2, fast) || !Copy(hSlow, 0, 2, slow) || !Copy(hBase, 0, 2, base) ||
      !Copy(hATR, 0, 51, atr)  || !Copy(hRSI, 0, 2, rsi) ||
      !Copy(hADX, 0, 2, adx)   || !Copy(hADX, 1, 2, dip) || !Copy(hADX, 2, 2, dim))
      return false;

   double c = r[1].close, o = r[1].open;
   double a = atr[1];
   double atrAvg = 0.0;
   for(int i = 1; i <= 50; i++) atrAvg += atr[i];
   atrAvg /= 50.0;

   bool htfBull = true, htfBear = true;
   if(InpUseHTF && !HTFTrend(hHTF, InpHTF, r[1].time, htfBull, htfBear))
      return false;
   if(InpUseHTF2)
   {
      bool b2 = true, s2 = true;
      if(!HTFTrend(hHTF2, InpHTF2, r[1].time, b2, s2))
         return false;
      htfBull = htfBull && b2;
      htfBear = htfBear && s2;
   }

   MqlDateTime bt;
   TimeToStruct(r[1].time, bt);
   bool inSession = !InpUseSession || (bt.hour >= InpSessionStart && bt.hour < InpSessionEnd);
   bool volOk  = !InpUseVol || a >= atrAvg * InpVolRatio;
   bool adxOkL = !InpUseADX || (adx[1] >= InpADXMin && dip[1] > dim[1]);
   bool adxOkS = !InpUseADX || (adx[1] >= InpADXMin && dim[1] > dip[1]);

   bool bull = fast[1] > slow[1] && slow[1] > base[1] && c > base[1];
   bool bear = fast[1] < slow[1] && slow[1] < base[1] && c < base[1];

   double lowL = DBL_MAX, highH = -DBL_MAX, lowC = DBL_MAX, highC = -DBL_MAX;
   for(int i = 1; i <= InpPullback; i++)
   {
      lowL  = MathMin(lowL, r[i].low);
      highH = MathMax(highH, r[i].high);
      lowC  = MathMin(lowC, r[i].close);
      highC = MathMax(highC, r[i].close);
   }
   bool pbL = lowL <= fast[1] && lowC > slow[1];
   bool pbS = highH >= fast[1] && highC < slow[1];

   bool trgL = c > fast[1] && c > o && c > r[2].high;
   bool trgS = c < fast[1] && c < o && c < r[2].low;

   bool rsiL = rsi[1] > 50.0 && rsi[1] < InpRSIMaxLong;
   bool rsiS = rsi[1] < 50.0 && rsi[1] > InpRSIMinShort;

   double swingLow = DBL_MAX, swingHigh = -DBL_MAX;
   for(int i = 1; i <= InpSwing; i++)
   {
      swingLow  = MathMin(swingLow, r[i].low);
      swingHigh = MathMax(swingHigh, r[i].high);
   }
   double slL = MathMin(swingLow - a * InpSLBuffer, c - a * InpMinSL);
   double slS = MathMax(swingHigh + a * InpSLBuffer, c + a * InpMinSL);

   bool buy  = bull && htfBull && adxOkL && volOk && inSession && pbL && trgL && rsiL && (c - slL) <= a * InpMaxSL;
   bool sell = bear && htfBear && adxOkS && volOk && inSession && pbS && trgS && rsiS && (slS - c) <= a * InpMaxSL;

   if(buy)       { dir = 1;  sl = slL; }
   else if(sell) { dir = -1; sl = slS; }
   return true;
}

//+------------------------------------------------------------------+
// Trend of a higher timeframe, using the HTF bar before the one that contains
// the signal bar (non-repainting). Returns false if data is not ready.
bool HTFTrend(const int handle, const ENUM_TIMEFRAMES tf, const datetime t, bool &bull, bool &bear)
{
   int hs = iBarShift(_Symbol, tf, t) + 1;
   double he[];
   ArraySetAsSeries(he, true);
   if(hs <= 0 || CopyBuffer(handle, 0, hs, 1, he) != 1)
      return false;
   double hc = iClose(_Symbol, tf, hs);
   if(hc == 0.0)
      return false;
   bull = hc > he[0];
   bear = hc < he[0];
   return true;
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
bool OpenTrade(const int dir, const double slLevel)
{
   int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double price   = dir == 1 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   double risk = (price - slLevel) * dir;
   if(risk <= minStop || risk <= 0.0)
   {
      Print("Price already beyond the stop level, signal skipped.");
      return false;
   }

   double sl  = NormalizeDouble(slLevel, digits);
   double tp1 = NormalizeDouble(price + dir * risk * InpTP1R, digits);
   double tp2 = NormalizeDouble(price + dir * risk * InpTP2R, digits);

   double total = InpFixedLot > 0.0 ? InpFixedLot : LotsForRisk(risk);
   double half  = NormalizeLots(total / 2.0);
   bool   ok;

   if(half > 0.0)
   {
      // Two legs: TP1 leg (Magic) and TP2 leg (Magic+1)
      trade.SetExpertMagicNumber(InpMagic);
      ok = dir == 1 ? trade.Buy(half, _Symbol, price, sl, tp1, InpComment + " TP1")
                    : trade.Sell(half, _Symbol, price, sl, tp1, InpComment + " TP1");
      if(!ok)
      {
         Print("TP1 leg failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
         return false;
      }
      trade.SetExpertMagicNumber(InpMagic + 1);
      ok = dir == 1 ? trade.Buy(half, _Symbol, 0.0, sl, tp2, InpComment + " TP2")
                    : trade.Sell(half, _Symbol, 0.0, sl, tp2, InpComment + " TP2");
      if(!ok)
         Print("TP2 leg failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      return true;
   }

   // Lot too small to split: one position to TP2, breakeven at TP1 still applies
   double lots = NormalizeLots(total);
   if(lots <= 0.0)
   {
      Print("Lot size below broker minimum for this risk, signal skipped.");
      return false;
   }
   trade.SetExpertMagicNumber(InpMagic + 1);
   ok = dir == 1 ? trade.Buy(lots, _Symbol, price, sl, tp2, InpComment)
                 : trade.Sell(lots, _Symbol, price, sl, tp2, InpComment);
   if(!ok)
      Print("Order failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   return ok;
}

//+------------------------------------------------------------------+
// Moves the TP2 leg's stop to its open price once price reaches the TP1 level.
void ManageBreakeven()
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic + 1)
         continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      if(tp == 0.0) continue;
      double tp1Price = open + (tp - open) * InpTP1R / InpTP2R;

      trade.SetExpertMagicNumber(InpMagic + 1);
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         if(bid >= tp1Price && sl < open && bid - open > minStop)
            trade.PositionModify(ticket, open, tp);
      }
      else
      {
         if(ask <= tp1Price && (sl > open || sl == 0.0) && open - ask > minStop)
            trade.PositionModify(ticket, open, tp);
      }
   }
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
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && (magic == InpMagic || magic == InpMagic + 1))
         return true;
   }
   return false;
}
//+------------------------------------------------------------------+
