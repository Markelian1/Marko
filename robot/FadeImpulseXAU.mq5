//+------------------------------------------------------------------+
//|                                               FadeImpulseXAU.mq5 |
//|  Robot per XAUUSD (grafik M5) sipas hyrjeve manuale:              |
//|  BUY pas nje renieje te forte (4332 -> 4302, 4303 -> 4281) dhe    |
//|  SELL pas nje ngritjeje te forte (4299 -> 4318).                  |
//|                                                                  |
//|  Rregulli (i testuar mbi M5 28.04.2025 - 23.09.2026):             |
//|  - Brenda 8 qirinjve M5 (40 min) cmimi levizi >= 200 pips.        |
//|  - Ekstremi (fundi per BUY, maja per SELL) eshte ne 2 qirinjte e  |
//|    fundit dhe qiriri i fundit u mbyll ne anen e kundert.          |
//|  - Hyrje ne treg, SL pas ekstremit + 5 pips (max 100 pips),       |
//|    TP = 5 here SL. Nese pas 2 oresh as SL as TP nuk jane prekur,  |
//|    pozicioni mbyllet me cmimin e tregut (v1.10).                  |
//|    Nje pozicion ne te njejten kohe.                               |
//|  Lot fiks, PA martingale.                                         |
//+------------------------------------------------------------------+
#property copyright "Marko"
#property version   "1.10"
#property description "Hyrje kundra levizjes se forte ne M5: BUY pas renies, SELL pas ngritjes. SL pas ekstremit, TP 3R."

#include <Trade\Trade.mqh>

input group "Madhesia e pozicionit"
input double InpLots            = 0.01;   // Loti per cdo hyrje
input double InpPipSize         = 0.10;   // 1 pip ne ar = 0.10$ levizje cmimi

input group "Levizja e forte"
input ENUM_TIMEFRAMES InpTF     = PERIOD_M5;
input int    InpWindowBars      = 8;      // Brenda sa qirinjve (8 x M5 = 40 min)
input int    InpMovePips        = 200;    // Levizja minimale (pips)
input int    InpExtremeBars     = 2;      // Ekstremi duhet te jete ne kaq qirinjte e fundit
input bool   InpAllowBuy        = true;   // BUY pas renies
input bool   InpAllowSell       = true;   // SELL pas ngritjes

input group "SL / TP"
input int    InpSLBufPips       = 5;      // SL pas ekstremit (pips)
input int    InpMaxSLPips       = 100;    // SL me i madh = pa hyrje
input double InpRR              = 5.0;    // TP = kaq here SL
input int    InpMaxTPPips       = 0;      // TP jo me larg se kaq pips (0 = pa kufi)
input int    InpMaxHoldMin      = 120;    // Mbyll pozicionin pas kaq minutash (0 = pa kufi)

input group "Kufizime"
input int    InpStartHour       = 9;      // Ora e serverit
input int    InpEndHour         = 21;
input int    InpMaxSpreadPips   = 4;
input int    InpMaxTradesPerDay = 3;      // Hyrje ne dite (0 = pa limit)
input double InpDailyLossStop   = 0;      // Ndalo per sot pas kesaj humbjeje (0 = pa limit)
input ulong  InpMagic           = 20260926;

CTrade   trade;
datetime g_lastBar = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpPipSize <= 0 || InpWindowBars < 2 || InpExtremeBars < 1 || InpRR <= 0)
   {
      Print("Parametra te gabuar");
      return INIT_PARAMETERS_INCORRECT;
   }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   PrintStats();
}

//+------------------------------------------------------------------+
void OnTick()
{
   CloseOldPositions();

   datetime bt = iTime(_Symbol, InpTF, 0);
   if(bt == 0 || bt == g_lastBar)
      return;
   g_lastBar = bt;

   if(CountMyPositions() > 0) return;
   if(!IsTradingHour())       return;
   if(!IsSpreadOk())          return;
   if(!AreDailyLimitsOk())    return;

   // Dritarja: qirinjte e mbyllur 1 .. InpWindowBars (1 = me i fundit)
   double mx = 0, mn = DBL_MAX;
   int    sMx = -1, sMn = -1;
   for(int s = 1; s <= InpWindowBars; s++)
   {
      double h = iHigh(_Symbol, InpTF, s);
      double l = iLow (_Symbol, InpTF, s);
      if(h == 0 || l == 0) return;
      if(h > mx) { mx = h; sMx = s; }
      if(l < mn) { mn = l; sMn = s; }
   }
   if(mx - mn < InpMovePips * InpPipSize) return;

   double o1  = iOpen (_Symbol, InpTF, 1);
   double c1  = iClose(_Symbol, InpTF, 1);
   double pip = InpPipSize;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // BUY: renie e forte (maja me heret se fundi), fundi i fresket, qiri jeshil
   if(InpAllowBuy && sMx > sMn && sMn <= InpExtremeBars && c1 > o1)
   {
      double sl   = mn - InpSLBufPips * pip;
      double risk = ask - sl;
      if(risk > 0 && risk <= InpMaxSLPips * pip)
      {
         double tp = ask + TPDistance(risk);
         if(!trade.Buy(NormalizeLots(InpLots), _Symbol, 0, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "BUY FADE"))
            Print("BUY deshtoi: ", trade.ResultRetcodeDescription());
      }
      return;
   }

   // SELL: ngritje e forte (fundi me heret se maja), maja e fresket, qiri i kuq.
   // SL/TP i SELL mbyllen me Ask, prandaj SL mbi majen + spread.
   if(InpAllowSell && sMn > sMx && sMx <= InpExtremeBars && c1 < o1)
   {
      double sl   = mx + InpSLBufPips * pip + (ask - bid);
      double risk = sl - bid;
      if(risk > 0 && risk <= InpMaxSLPips * pip)
      {
         double tp = bid - TPDistance(risk);
         if(!trade.Sell(NormalizeLots(InpLots), _Symbol, 0, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "SELL FADE"))
            Print("SELL deshtoi: ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
double TPDistance(const double risk)
{
   double d = InpRR * risk;
   if(InpMaxTPPips > 0) d = MathMin(d, InpMaxTPPips * InpPipSize);
   return d;
}

//+------------------------------------------------------------------+
//| Levizja e kthimit zakonisht ndodh shpejt: pas InpMaxHoldMin       |
//| minutash pozicioni mbyllet me cmimin e tregut.                    |
//+------------------------------------------------------------------+
void CloseOldPositions()
{
   if(InpMaxHoldMin <= 0) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsMyPosition()) continue;
      if(TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME) >= InpMaxHoldMin * 60)
         if(!trade.PositionClose(ticket))
            Print("Mbyllja me kohe deshtoi: ", trade.ResultRetcodeDescription());
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

   string types[2] = {"BUY FADE", "SELL FADE"};
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

   Print("===== FadeImpulseXAU: rezultati (", _Symbol, ") =====");
   for(int k = 0; k < 2; k++)
   {
      double wr = cnt[k] > 0 ? 100.0 * won[k] / cnt[k] : 0.0;
      PrintFormat("%-9s : %4d hyrje | fitues %5.1f%% | neto %9.2f", types[k], cnt[k], wr, net[k]);
   }
}
//+------------------------------------------------------------------+
