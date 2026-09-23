# KeyLevelXAU: robot që hyn vetëm te nivelet kyçe (MT5)

`KeyLevelXAU.mq5` tregton si hyrjet manuale: **SELL te rezistenca, BUY te mbështetja**, vetëm kur plotësohen të gjitha kushtet.

1. **Nivelet kyçe:** majat dhe fundet e rëndësishme në **M15** (2 ditët e fundit) + High/Low e ditës së kaluar. Vizatohen me vija të verdha.
2. **Prekja:** çmimi arrin nivelin (brenda 15 pips) ose e kalon me bisht (deri në 40 pips). Më thellë = niveli u thye, nuk tregtohet më sot.
3. **Konfirmimi në M1 (brenda 15 qirinjve):** qiriri mbyllet përsëri mbrapa nivelit dhe nën fundin (ose mbi majën) e 3 qirinjve të fundit.
4. **SL** pas bishtit + 5 pips (20–60 pips). **TP** = niveli kyç tjetër. Hyn vetëm nëse deri aty ka të paktën **2R**.
5. **1 ose 2 pozicione:** nëse objektivi është ≥ 3R hap 2 (TP1 = 1R, TP2 = niveli tjetër, pastaj break-even), përndryshe 1.
6. Çdo nivel përdoret **një herë në ditë**, maksimumi **4 hyrje në ditë**, vetëm **09:00–21:00** (London + New York).

Në fund të testit, tab-i **Journal** tregon hyrjet, fituesit dhe fitimin neto për BUY dhe SELL.

# TrendScalperXAU: robot për arin (MT5)

Robot (Expert Advisor) për **MetaTrader 5** me të njëjtën logjikë si indikatori `TrendScalperXAU.pine`.
Punon në grafikun **M1** (i ndryshueshëm) dhe **nuk përdor martingale**.

## Si funksionon

**1. Hyrjet TREND (3 timeframe):**
- Trendi merret nga **H1, M15 dhe M5** (EMA 21 / EMA 50). M5 jep drejtimin, M15 nuk duhet të jetë kundër tij.
- Hyrja: qiriri i fundit **preku EMA 20** dhe u mbyll në drejtim të trendit. SL = 30 pips.
- Kur M5 është kundër H1 = **KTHIM**: të dy pozicionet mbyllen te TP1.

**2. Hyrjet SWEEP (likuiditet):**
- Roboti mban mend **fundet dhe majat** e fundit (swing), aty ku rrinë stop-et.
- Kur çmimi **i kalon me bisht** (deri në 30 pips) dhe brenda 2 qirinjve **mbyllet përsëri mbrapa nivelit**, hyn në anën e kundërt, **pavarësisht trendit**.
- SL = pas bishtit + 5 pips (min 15, max 40). Nëse ka pozicion të hapur në anën e kundërt, e mbyll.

**3. Hyrjet RETEST (niveli i thyer):**
- Kur një **fund thyhet poshtë** (qiriri mbyllet nën të), ai bëhet **rezistencë**. Kur çmimi largohet të paktën 20 pips dhe kthehet ta prekë, hyn **SELL**.
- Kur një **majë thyhet lart**, ajo bëhet **mbështetje**. Kur çmimi kthehet ta prekë, hyn **BUY**.
- SL = pas nivelit/bishtit + 5 pips (min 15, max 40). Niveli vlen për 120 qirinj.

Përparësia: **SWEEP > RETEST > TREND**.

**Drejtimi i kundërt (`InpReverse`, parazgjedhur `true`):** çdo sinjal ekzekutohet në anën e kundërt.
Ku strategjia do bënte BUY, roboti bën SELL dhe anasjelltas. SL dhe TP mbeten me të njëjtën distancë në pips.
Vendose `false` për drejtimin origjinal.

**Çdo hyrje hap 2 pozicione:** TP1 = **20 pips**, TP2 = **50 pips**. Pas TP1, SL e pozicionit 2 kalon 1 pip mbi hyrje.
Komentet e pozicioneve (`SWEEP TP1`, `RETEST TP2`, `TREND TP2`, `KTHIM TP1`) tregojnë pse hyri roboti.

> 1 pip në ar = 0.10 $ lëvizje çmimi. Me 0.01 lot: 20 pips = 2 $, 50 pips = 5 $.

## Parametrat kryesorë

| Parametri | Vlera | Çfarë bën |
|---|---|---|
| `InpReverse` | true | Strategjia e kundërt (BUY ↔ SELL) |
| `InpLots` | 0.01 | Loti për secilin pozicion |
| `InpTP1Pips` / `InpTP2Pips` | 20 / 50 | Objektivat |
| `InpSLPips` | 30 | SL për hyrjet TREND |
| `InpEntryTF` | M1 | Grafiku ku kërkohen hyrjet |
| `InpTFHigh` / `InpTFMid` / `InpTFLow` | H1 / M15 / M5 | Trendi nga 3 timeframe |
| `InpAllowKthim` | true | Lejon hyrje kundër trendit H1 (vetëm TP1) |
| `InpUseSweep` | true | Hyrjet pas marrjes së likuiditetit |
| `InpEqTolPips` | 20 | Toleranca për fundet/majat e barabarta |
| `InpNeedEqual` | false | true = vetëm fundet/majat e dyfishta |
| `InpMaxSweepPips` | 30 | Më thellë se kaq = thyerje, jo sweep |
| `InpSweepMinSL` / `InpSweepMaxSL` | 15 / 40 | Kufijtë e SL për SWEEP |
| `InpFlipOpposite` | true | SWEEP mbyll pozicionin e kundërt |
| `InpUseRetest` | true | Hyrjet te niveli i thyer (rezistencë ↔ mbështetje) |
| `InpRetAwayPips` / `InpRetTolPips` | 20 / 5 | Sa larg duhet të shkojë çmimi / sa afër nivelit quhet prekje |
| `InpMaxSpreadPips` | 4 | Nuk hyn kur spread-i është i madh |
| `InpStartHour` / `InpEndHour` | 3 / 21 | Orari (ora e serverit) |
| `InpDailyLossStop` | 12 | Ndalon për sot pas kësaj humbjeje |
| `InpMaxSetupsPerDay` | 10 | Numri maksimal i hyrjeve në ditë |

## Si ta instalosh

1. Hap **MetaTrader 5 në kompjuter** (robotët nuk punojnë në aplikacionin e telefonit).
2. `File → Open Data Folder → MQL5 → Experts` dhe kopjo aty `TrendScalperXAU.mq5`.
3. Hape me **MetaEditor** dhe shtyp **F7 (Compile)**. Nuk duhet të ketë asnjë error.
4. Në MT5: `Navigator → Expert Advisors → TrendScalperXAU` dhe tërhiqe mbi grafikun **XAUUSD.r**.
5. Aktivizo butonin **Algo Trading**.

## Para se ta përdorësh me para reale

1. **Backtest:** `View → Strategy Tester`, zgjidh robotin, XAUUSD.r, modelin
   *"Every tick based on real ticks"* dhe të paktën **3–6 muajt e fundit**.
   Shiko fitimin neto, **drawdown-in maksimal** dhe numrin e ditëve me humbje.
2. **Demo 2–4 javë** me të njëjtin broker.
3. Vetëm pastaj në **llogari reale me 0.01 lot**.

## E rëndësishme

- Ky robot **nuk është kopje** e robotit nga fotot. Kodi i atij roboti nuk dihet; ky ndjek të njëjtën ide.
- Për hyrjet SWEEP roboti përdor gjithmonë qirinj të mbyllur, prandaj hyn pak më vonë se indikatori në grafik (në hapjen e qiririt tjetër).
- Kodi **nuk është testuar ende** në MT5. Mund të ketë nevojë për rregullime pas kompilimit dhe backtest-it.
- **Asnjë robot nuk garanton fitim çdo ditë.** Me 0.01 lot, 30–40 € në ditë kërkon rreth 300–400 pips neto, pra shumë hyrje fituese. Në ditë pa trend, ky robot do të hyjë pak ose do të humbasë.

## Indikatori për TradingView (Pine Script)

`TrendScalperXAU.pine` ka të njëjtën logjikë si roboti dhe të tregon në grafik si funksionon:

- **BUY / SELL** në qiririn ku jepet sinjali
- vijat e **hyrjes (gri)**, **SL (e kuqe)**, **TP1 (e ndërprerë)**, **TP2 (jeshile)**, dhe **break-even (portokalli)** pas TP1
- etiketa me rezultatin në pips kur mbyllet çdo hyrje
- sfondi **jeshil** kur trendi është lart dhe **i kuq** kur është poshtë
- tabela lart djathtas: hyrjet, fituesit, humbësit, win rate, pips gjithsej dhe fitimi në $

**Si ta vendosësh:**

1. Hap TradingView → grafiku **XAUUSD**, timeframe **5 minuta**.
2. Poshtë hap **Pine Editor**, fshi kodin që është aty dhe ngjit gjithë përmbajtjen e `TrendScalperXAU.pine`.
3. Kliko **Save**, pastaj **Add to chart**.
4. Ndrysho TP, SL dhe EMA-t te ⚙️ (Settings) e indikatorit.
5. Për njoftime: **Alert → Condition: TSXAU → TSXAU Buy / TSXAU Sell**.

> Rezultatet në tabelë janë simulim mbi qirinjtë e grafikut. Nuk përfshijnë spread-in dhe komisionin, dhe kur SL dhe TP preken në të njëjtin qiri llogaritet SL. Në tregtim real rezultati do të jetë pak më i ulët.

## Indikatori SMC për 1 minutë (Likuiditet + Order Block)

`SMCScalperXAU.pine` është për grafikun **XAUUSD 1m**. Hyn vetëm kur:

- **merret likuiditeti (LIQ):** çmimi kalon me bisht një swing high/low ose High/Low e ditës së kaluar dhe mbyllet mbrapa nivelit.
  Kur merret likuiditeti poshtë hyn **BUY**, kur merret lart hyn **SELL**.
- **preket Order Block-u (OB):** pas një thyerjeje strukture (BOS), qiriri i fundit në drejtim të kundërt bëhet OB (kutia jeshile/e kuqe).
  Kur çmimi kthehet dhe e prek për herë të parë, te OB bullish hyn **BUY** dhe te OB bearish hyn **SELL**.
- **trendi 15m** (EMA 50/200) është në të njëjtin drejtim. Filtri mund të çaktivizohet.

SL vendoset **pas bishtit ose pas OB-së + 5 pips**, minimum 15 dhe maksimum 40 pips. Nëse del më i madh, hyrja anulohet.
TP1 = 20 pips, TP2 = 50 pips, dhe pas TP1 SL-ja kalon te hyrja (break-even).
Në grafik, etiketa **BUY LIQ / BUY OB / SELL LIQ+OB** tregon pse hyri, dhe ✕ tregon ku u mor likuiditeti.

## Liquidity Reversal (5m): hyrje pas marrjes së likuiditetit në range

`LiquidityReversalXAU.pine` ndërton hyrjen e tipit BUY 4277.75 të 23.09 (cTrader, m5):

1. Gjen **fundet/majat e barabarta** (equal lows/highs): aty rrinë stop-et, pra likuiditeti.
2. Pret që çmimi t'i **kalojë me bisht** (sweep), por jo më shumë se 40 pips.
3. Kur brenda 2 qirinjve **mbyllet përsëri mbrapa nivelit** → hyn në anën e kundërt.
4. **SL** pas bishtit + 5 pips, **TP1 = 1R**, **TP2 = likuiditeti më i afërt në anën tjetër** (vetëm nëse jep të paktën RR 1.5).
5. Pas TP1: break-even dhe **trailing SL**, që ngjit SL-në mbi hyrje.

Tabela tregon edhe **pips neto pas spread-it** (2 pips për pozicion, i ndryshueshëm), që rezultati të jetë realist.
