# TrendScalperXAU: robot për arin (MT5)

Robot (Expert Advisor) për **MetaTrader 5**, i ndërtuar sipas asaj që tregon historiku i 23.09.2026:
ndjek trendin, hap dy pozicione në të njëjtin nivel (TP1 i shpejtë dhe TP2 që vrapon) dhe **nuk përdor martingale**.

## Si funksionon

1. **Trendi (M15):** EMA 50 mbi EMA 200 dhe çmimi mbi EMA 50 → vetëm **buy**.
   EMA 50 nën EMA 200 dhe çmimi nën EMA 50 → vetëm **sell**. Përndryshe nuk hyn.
2. **Hyrja (M5):** qiriri i fundit **preku EMA 20** (pullback) dhe u mbyll në drejtim të trendit.
3. **Hap 2 pozicione 0.01 lot:**
   - Pozicioni 1: TP = **20 pips**
   - Pozicioni 2: TP = **50 pips**
   - SL = **30 pips** për të dyja
4. **Break-even:** kur merret TP1, SL e pozicionit 2 kalon 1 pip mbi hyrje. Nga ky moment ky trade nuk humb.
5. **Vetëm një hyrje në të njëjtën kohë.** Pozicioni i ri hapet vetëm pasi mbyllen të mëparshmit.

> 1 pip në ar = 0.10 $ lëvizje çmimi. Me 0.01 lot: 20 pips = 2 $, 50 pips = 5 $.

## Rezultatet e mundshme të një hyrjeje (0.01 lot)

| Skenari | Pips | Fitimi |
|---|---|---|
| SL para TP1 | −60 | −6 $ |
| TP1, pastaj break-even | +21 | ~+2.1 $ |
| TP1 + TP2 | +70 | +7 $ |

## Parametrat

| Parametri | Vlera fillestare | Çfarë bën |
|---|---|---|
| `InpLots` | 0.01 | Loti për secilin pozicion |
| `InpPipSize` | 0.10 | Madhësia e 1 pip-i në ar |
| `InpTP1Pips` / `InpTP2Pips` | 20 / 50 | Objektivat |
| `InpSLPips` | 30 | Stop loss |
| `InpBreakEven` | true | SL në hyrje pas TP1 |
| `InpTrendTF` | M15 | Timeframe-i i trendit |
| `InpEntryTF` | M5 | Timeframe-i i hyrjes |
| `InpMaxSpreadPips` | 4 | Nuk hyn kur spread-i është i madh |
| `InpStartHour` / `InpEndHour` | 3 / 21 | Orari i hyrjeve (ora e serverit) |
| `InpDailyProfitStop` | 0 | Ndalon për sot pas këtij fitimi (0 = pa limit) |
| `InpDailyLossStop` | 12 | Ndalon për sot pas kësaj humbjeje |
| `InpMaxSetupsPerDay` | 10 | Numri maksimal i hyrjeve në ditë |
| `InpMagic` | 20260923 | Numri që dallon trade-t e robotit |

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
- Kodi **nuk është testuar ende** në MT5. Mund të ketë nevojë për rregullime pas kompilimit dhe backtest-it.
- **Asnjë robot nuk garanton fitim çdo ditë.** Me 0.01 lot, 30–40 € në ditë kërkon rreth 300–400 pips neto, pra shumë hyrje fituese. Në ditë pa trend, ky robot do të hyjë pak ose do të humbasë.
