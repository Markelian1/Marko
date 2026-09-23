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
