# TrendEA Pro — backtest on XAUUSD 5m history (MT5 export)

The data covers 100,000 five-minute bars from 2025-04-22 to 2026-09-17, in broker server time (UTC+3 in summer).
Each trade pays the recorded spread plus $0.05 of slippage.
Results are measured in R, where 1R is the amount risked on one trade.

## Method
- `bt.py` reproduces the Pine logic of `TrendEA_Pro_*.pine` in Python.
- `opt.py` runs a grid of 1,536 combinations. It optimises on the first 70% of the data (to 2026-04-16) and checks each combination on the last 30%.

## Findings
- With the original defaults (5m chart, 15m HTF), the strategy roughly **broke even** (PF 0.98).
- The best in-sample settings (PF ~1.6) **failed out of sample** (PF < 1). This is overfitting.
- A **stable cluster** does well in both periods. Nearby settings also give PF 1.2–1.5.

| Setting | Value |
|---|---|
| Chart timeframe | **15m** (5m has no edge: PF 1.00) |
| HTF timeframe | 60 (240 is similar) |
| Min ADX | 20 |
| TP1 / TP2 | 1R (50%) / 3R |
| SL buffer | 0.8 × ATR |
| Breakeven after TP1 | on |
| Session | 15:00–23:00 server = **12:00–20:00 UTC** |

Results with these settings:
- **Full period:** 158 trades, 54% win rate, PF 1.31, +22.6R, max drawdown 10.2R.
- **In-sample / out-of-sample:** PF 1.30 / 1.34.
- **Shorts:** PF 1.43. **Longs:** PF 1.21.
- **With $0.30 slippage:** PF 1.28.

### Results by quarter

| Quarter | Trades | PF | Net R |
|---|---|---|---|
| 2025Q2 | 18 | 2.26 | +8.9 |
| 2025Q3 | 20 | 1.54 | +3.8 |
| 2025Q4 | 24 | 1.36 | +4.4 |
| 2026Q1 | 29 | 1.05 | +0.9 |
| 2026Q2 | 38 | 0.96 | -0.7 |
| 2026Q3 | 29 | 1.48 | +5.4 |

## Caveats
- The edge is modest. At 1% risk per trade, +22.6R is about +22% over 17 months, with drawdowns of about 10%.
- TradingView's gold feed and Pine's indicator seeding differ slightly from this Python replica, so trade counts will not match exactly.
- The results come from one instrument and 17 months of data. Forward-test the strategy on a demo account before trading it live.

Run it yourself with: `pip install pandas numpy numba && python3 opt.py XAUUSD_history.csv`

## v2.1: structural improvements (`bt2.py`)

The first MT5 Strategy Tester run covered Jan–Sep 2026 and gave PF 1.11, +4.6% and a 10.6% drawdown. That matches the Python replica for the same window (PF 1.12, +5.6R, 10.2R drawdown).

Each idea below is a change to how the strategy trades, not a parameter tweak. An idea was accepted only if it improved **both** 2025 and 2026.

| Variant | All PF | Net R | Max DD (R) | 2025 PF | 2026 PF |
|---|---|---|---|---|---|
| Baseline v2.0 | 1.31 | 22.6 | 10.2 | 1.65 | 1.12 |
| **+ H4 trend filter (adopted)** | **1.38** | **22.8** | **7.6** | 1.61 | **1.23** |
| Chandelier trail 3×ATR after TP1 | 1.26 | 20.1 | 9.0 | 1.43 | 1.15 |
| Buy/sell-stop entry above the trigger bar | 1.24 | 15.4 | 9.2 | 1.48 | 1.09 |
| Time exit after 32 bars | 1.24 | 16.2 | 7.8 | 1.46 | 1.10 |

With the H4 filter, the nearby settings still give PF 1.21–1.46: ADX 15/25, TP2 2.5/4, session ±1h and cooldown 5/20.
Session 16–23 and cooldown 20 looked even better, but they were **not** adopted, to avoid tuning to this sample.
On the 5m chart the edge disappears (2025 PF 0.96), so keep using 15m.

## Session strategies research (`sess.py`, `research.py`, `asia.py`)

The goal was more trades per day by adding a strategy for each session.
A strategy is judged by how its whole parameter neighbourhood does, not by the best single combination.

| Idea | Trades/day | Neighbourhood result | Verdict |
|---|---|---|---|
| Asia mean reversion (M5 Bollinger fade, RSI, ADX<25) | ~0.3 | 324 combos, median PF 0.96, only 9% have PF≥1.1 in both years | Rejected: the best combos were luck |
| London breakout of the Asian range (M5) | ~0.3 | 72 combos, median PF 1.02 in 2025 vs 1.92 in 2026 | Regime-dependent: no edge in 2025 |
| NY opening-range breakout | 0.5–1.5 | PF 1.00–1.14, 2026 ≈ 1.0 | Rejected |
| TrendEA Pro split by session (M15, all day) | — | Asia PF 0.96, London 0.74, **NY 1.79** | Keep NY only |

Conclusion: on XAUUSD, only the NY trend-pullback has a robust edge in this data.
To get more trades, run the same EA on more symbols rather than loosening its filters on gold.

## Re-test on the FP Trading broker feed (M5 2025-04-28 → 2026-09-23, M1 2026-06-15 → 2026-09-23)

Prices match the first dataset (median difference $0.08), but the real spread is about **4× wider** (20 points, i.e. $0.20, instead of 5).

| Variant | Trades | PF | Net R | Max DD (R) | 2025 PF | 2026 PF |
|---|---|---|---|---|---|---|
| v2.0 (H1 filter only) | 154 | 1.27 | 19.3 | 10.9 | 1.76 | 1.03 |
| **v2.1 (H1 + H4), M15** | 133 | **1.35** | **21.1** | **6.8** | 1.75 | 1.13 |
| v2.1 on M5 | 201 | 1.05 | 4.6 | 16.1 | 0.87 | 1.26 |
| v2.1 on all sessions | 269 | 1.11 | 14.7 | 11.1 | 1.34 | 0.94 |
| v2.1 on M1, NY session (Jun–Sep) | 162 | 1.02 | 1.4 | 12.6 | — | — |
| v2.1 on M1, all sessions (Jun–Sep) | 451 | 0.92 | -20.6 | 33.9 | — | — |

- v2.1 on M15 is positive in **every quarter** (PF 1.04–2.11). Every nearby setting is positive in both years.
- The M1 exit check re-played the Jun–Sep 2026 trades on 1-minute bars. The net R was the same (5.61R vs 5.60R) and only one trade had a different outcome, so the M15 bar model is accurate.
- Faster timeframes and more sessions add trades, but the edge disappears.
