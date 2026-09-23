//+------------------------------------------------------------------+
//|                                                LimitLevelXAU.mq5 |
//|  Robot per XAUUSD sipas hyrjeve manuale te 23.09:                 |
//|  - Nivelet: majat/fundet ne H1 qe cmimi ende nuk i ka kaluar,     |
//|    + High/Low e dites se kaluar.                                  |
//|  - SELL LIMIT pak MBI majen me te afert (aty ku merret            |
//|    likuiditeti), BUY LIMIT pak NEN fundin me te afert.            |
//|  - SL i vogel fiks (35 pips), TP i madh (3R).                     |
//|  - Pas 1R: SL ne hyrje (break-even).                              |
//|  - Urdhrat vendosen para se cmimi te arrije, jo pas konfirmimit.  |
//|  Lot fiks, PA martingale.                                         |
//+------------------------------------------------------------------+
#property copyright "Marko"
#property version   "1.00"
#property description "SELL LIMIT mbi majat dhe BUY LIMIT nen fundet e H1, SL i vogel, TP 3R. Pa martingale."

#include <Trade\Trade.mqh>

input group "Madhesia e pozicionit"
input double InpLots            = 0.01;   // Loti per cdo hyrje
input double InpPipSize         = 0.10;   // 1 pip ne ar = 0.10$ levizje cmimi

input group "Nivelet"
input ENUM_TIMEFRAMES InpLevelTF = PERIOD_H1;
input int    InpPivot           = 3;      // Forca e majes/fundit (qirinj majtas/djathtas)
input int    InpLookback        = 120;    // Sa qirinj mbrapa (120 x H1 = 5 dite)
input bool   InpUsePrevDay      = true;   // Perfshi High/Low e dites se kaluar
input int    InpMinDistPips     = 30;     // Niveli duhet te jete te pakten kaq larg cmimit
input int    InpMaxDistPips     = 300;    // dhe jo me larg se kaq

input group "Urdhri LIMIT"
input int    InpOffsetPips      = 10;     // SELL LIMIT kaq pips MBI maje, BUY LIMIT kaq NEN fund
input int    InpSLPips          = 35;     // Stop loss
input double InpRR              = 3.0;    // TP = kaq here SL
input double InpBEAtR           = 1.0;    // Kur fitimi arrin kaq R, SL ne hyrje (0 = pa break-even)
input int    InpBEOffsetPips    = 1;
input bool   InpSellSpreadAdj   = true;   // SELL: SL/TP zhvendosen me spread-in (mbyllen kur Bid i prek)

input group "Kufizime"
input int    InpStartHour       = 9;      // Ora e serverit kur vendosen urdhrat
input int    InpEndHour         = 21;     // Pas kesaj ore urdhrat e pa-mbushur fshihen
input int    InpMaxSpreadPips   = 4;
input int    InpMaxTradesPerDay = 3;      // Hyrje ne dite (0 = pa limit)
input double InpDailyLossStop   = 0;      // Ndalo per sot pas kesaj humbjeje (0 = pa limit)
input ulong  InpMagic           = 20260925;

CTrade   trade;
double   g_used[];            // nivelet e tregtuara sot
int      g_usedDay    = -1;
ulong    g_buyTicket  = 0;
ulong    g_sellTicket = 0;
double   g_buyLevel   = 0;
double   g_sellLevel  = 0;
datetime g_lastBar    = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpPipSize <= 0 || InpPivot < 1 || InpSLPips <= 0 || InpRR <= 0)
   {
      Print("Parametra te gabuar");
      return INIT_PARAMETERS_INCORRECT;
   }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   DeleteMyPendings();        // urdhra te mbetur nga nje nisje e meparshme
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteMyPendings();
   PrintStats();
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageBreakEven();
   CheckFilled();

   // Urdhrat perditesohen nje here ne minute
   datetime bt = iTime(_Symbol, PERIOD_M1, 0);
   if(bt == 0 || bt == g_lastBar)
      return;
   g_lastBar = bt;
   ResetUsedIfNewDay();

   if(!IsTradingHour() || !AreDailyLimitsOk() || CountMyPositions() > 0)
   {
      DeleteMyPendings();
      return;
   }
   if(!IsSpreadOk())
      return;

   UpdatePending(-1, FindLevel(true));    // SELL LIMIT mbi majen me te afert
   UpdatePending( 1, FindLevel(false));   // BUY LIMIT nen fundin me te afert
}

//+------------------------------------------------------------------+
//| Maja (isHigh) ose fundi me i afert qe cmimi ende nuk e ka kaluar  |
//+------------------------------------------------------------------+
double FindLevel(const bool isHigh)
{
   double pip  = InpPipSize;
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double best = 0;

   for(int p = InpPivot + 1; p <= InpLookback; p++)
   {
      if(!IsPivot(p, isHigh)) continue;
      double v = isHigh ? iHigh(_Symbol, InpLevelTF, p) : iLow(_Symbol, InpLevelTF, p);

      // I pa-prekur: asnje qiri pas tij (perfshi qiririn aktual) nuk e ka kaluar
      int idx = isHigh ? iHighest(_Symbol, InpLevelTF, MODE_HIGH, p, 0) : iLowest(_Symbol, InpLevelTF, MODE_LOW, p, 0);
      if(idx < 0) continue;
      double ext = isHigh ? iHigh(_Symbol, InpLevelTF, idx) : iLow(_Symbol, InpLevelTF, idx);
      if(isHigh ? ext > v : ext < v) continue;

      if(IsCandidate(v, isHigh, bid) && (best == 0 || (isHigh ? v < best : v > best)))
         best = v;
   }

   if(InpUsePrevDay)
   {
      double pd    = isHigh ? iHigh(_Symbol, PERIOD_D1, 1) : iLow(_Symbol, PERIOD_D1, 1);
      double today = isHigh ? iHigh(_Symbol, PERIOD_D1, 0) : iLow(_Symbol, PERIOD_D1, 0);
      bool   taken = isHigh ? today > pd : today < pd;
      if(pd > 0 && !taken && IsCandidate(pd, isHigh, bid) && (best == 0 || (isHigh ? pd < best : pd > best)))
         best = pd;
   }
   return best;
}

//+------------------------------------------------------------------+
bool IsCandidate(const double v, const bool isHigh, const double bid)
{
   double dist = (isHigh ? v - bid : bid - v) / InpPipSize;
   if(dist < InpMinDistPips || dist > InpMaxDistPips) return false;
   for(int i = 0; i < ArraySize(g_used); i++)
      if(MathAbs(g_used[i] - v) < InpPipSize) return false;
   return true;
}

//+------------------------------------------------------------------+
bool IsPivot(const int p, const bool isHigh)
{
   double v = isHigh ? iHigh(_Symbol, InpLevelTF, p) : iLow(_Symbol, InpLevelTF, p);
   if(v == 0) return false;
   for(int j = 1; j <= InpPivot; j++)
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
//| Vendos ose zhvendos urdhrin LIMIT te niveli (0 = fshi urdhrin)    |
//+------------------------------------------------------------------+
void UpdatePending(const int dir, const double level)
{
   ulong ticket = dir < 0 ? g_sellTicket : g_buyTicket;

   if(level == 0)
   {
      DeleteTicket(dir);
      return;
   }

   double pip   = InpPipSize;
   double price = level - dir * InpOffsetPips * pip;
   double adj   = (dir < 0 && InpSellSpreadAdj) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID) : 0;
   double sl    = NormalizeDouble(price - dir * InpSLPips * pip + adj, _Digits);
   double tp    = NormalizeDouble(price + dir * InpRR * InpSLPips * pip + adj, _Digits);
   price        = NormalizeDouble(price, _Digits);

   // Urdhri ekziston ne te njejtin cmim: s'ka nevoje per ndryshim
   if(ticket != 0 && OrderSelect(ticket) && MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - price) < pip)
      return;

   DeleteTicket(dir);

   double lots = NormalizeLots(InpLots);
   string cmt  = (dir < 0 ? "SELL LMT " : "BUY LMT ") + DoubleToString(level, _Digits);
   bool   ok   = dir < 0 ? trade.SellLimit(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt)
                         : trade.BuyLimit (lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt);
   if(!ok)
   {
      Print(cmt, " deshtoi: ", trade.ResultRetcodeDescription());
      return;
   }
   if(dir < 0) { g_sellTicket = trade.ResultOrder(); g_sellLevel = level; }
   else        { g_buyTicket  = trade.ResultOrder(); g_buyLevel  = level; }
}

//+------------------------------------------------------------------+
void DeleteTicket(const int dir)
{
   ulong ticket = dir < 0 ? g_sellTicket : g_buyTicket;
   if(dir < 0) g_sellTicket = 0; else g_buyTicket = 0;   // fshirje nga roboti, jo mbushje
   if(ticket != 0 && OrderSelect(ticket))
      trade.OrderDelete(ticket);
}

//+------------------------------------------------------------------+
void DeleteMyPendings()
{
   g_buyTicket  = 0;
   g_sellTicket = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      trade.OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
//| Urdhri u mbush: niveli nuk tregtohet me sot, urdhri tjeter fshihet|
//+------------------------------------------------------------------+
void CheckFilled()
{
   bool filled = false;
   if(g_sellTicket != 0 && !OrderSelect(g_sellTicket))
   {
      MarkUsed(g_sellLevel);
      g_sellTicket = 0;
      filled = true;
   }
   if(g_buyTicket != 0 && !OrderSelect(g_buyTicket))
   {
      MarkUsed(g_buyLevel);
      g_buyTicket = 0;
      filled = true;
   }
   if(filled)
      DeleteMyPendings();
}

//+------------------------------------------------------------------+
void MarkUsed(const double level)
{
   int n = ArraySize(g_used);
   ArrayResize(g_used, n + 1);
   g_used[n] = level;
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
//| Kur fitimi arrin InpBEAtR x SL, SL kalon ne hyrje                 |
//+------------------------------------------------------------------+
void ManageBreakEven()
{
   if(InpBEAtR <= 0) return;
   double pip     = InpPipSize;
   double trigger = InpBEAtR * InpSLPips * pip;
   double minStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsMyPosition()) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = NormalizeDouble(open + InpBEOffsetPips * pip, _Digits);
         if(bid - open >= trigger && sl < newSL && bid - newSL > minStop)
            if(!trade.PositionModify(ticket, newSL, tp))
               Print("Break-even deshtoi: ", trade.ResultRetcodeDescription());
      }
      else
      {
         double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = NormalizeDouble(open - InpBEOffsetPips * pip, _Digits);
         if(open - ask >= trigger && (sl == 0 || sl > newSL) && newSL - ask > minStop)
            if(!trade.PositionModify(ticket, newSL, tp))
               Print("Break-even deshtoi: ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
bool AreDailyLimitsOk()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   t.hour = 0; t.min = 0; t.sec = 0;
   if(!HistorySelect(StructToTime(t), TimeCurrent() + 60))
      return true;

   double pl     = 0;
   int    trades = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != (long)InpMagic) continue;
      if(HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN) trades++;
      pl += HistoryDealGetDouble(deal, DEAL_PROFIT)
          + HistoryDealGetDouble(deal, DEAL_COMMISSION)
          + HistoryDealGetDouble(deal, DEAL_SWAP);
   }
   if(InpMaxTradesPerDay > 0 && trades >= InpMaxTradesPerDay) return false;
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

   string types[2] = {"BUY LMT", "SELL LMT"};
   int    cnt[2]   = {0, 0};
   int    won[2]   = {0, 0};
   double net[2]   = {0, 0};

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
         if(t >= 0) net[t] += pl;
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

   Print("===== LimitLevelXAU: rezultati (", _Symbol, ") =====");
   for(int k = 0; k < 2; k++)
   {
      double wr = cnt[k] > 0 ? 100.0 * won[k] / cnt[k] : 0.0;
      PrintFormat("%-8s : %4d hyrje | fitues %5.1f%% | neto %9.2f", types[k], cnt[k], wr, net[k]);
   }
}
//+------------------------------------------------------------------+
