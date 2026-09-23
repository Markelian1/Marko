# TrendEA for TradingView (Pine Script v6)

This folder has two scripts. Both use the same logic as the MetaTrader 5 EA in `../trading-ea/`.

| File | Type | Use it for |
|------|------|------------|
| `TrendEA_Strategy.pine` | `strategy()` | Backtesting in the **Strategy Tester** (net profit, drawdown, list of trades) and strategy alerts |
| `TrendEA_Indicator.pine` | `indicator()` | Signals on the chart, SL/TP guide lines, a status panel and alerts you can pick from the alert menu |

## TrendEA Pro (recommended)

`TrendEA_Pro_Indicator.pine` / `TrendEA_Pro_Strategy.pine` give fewer, higher-quality signals. A signal fires only when **all** of these agree:

1. The EMAs are in trend order: fast > slow > 200 for longs (mirrored for shorts).
2. The higher-timeframe trend (1h by default) points the same way. It uses closed HTF bars, so it doesn't repaint.
3. ADX is at least 20 and DI+/DI− agree with the direction.
4. Price pulled back to the fast EMA without closing through the slow EMA.
5. A confirmation candle closes back with the trend and beyond the previous bar.
6. RSI shows momentum without being overextended, volatility isn't dead, and the session (12:00–20:00 UTC) is open.

The indicator gives one trade at a time: no new signal appears until the open one hits SL or TP.
- **SL:** placed beyond the recent swing plus an ATR buffer. If it would be too wide, the signal is skipped.
- **TP1:** 1R, closing 50% of the position.
- **TP2:** 3R.
- **Breakeven:** the stop moves to breakeven after TP1.

Use it on the **15m** chart. These defaults come from a backtest on XAUUSD history; see `backtest/RESULTS.md`.

Every signal is scored on the chart (✔ +1.5R / ✖ -1R). A panel shows the win rate, net R and profit factor.

## Logic (basic version)

- **Buy:** the fast EMA crosses above the slow EMA and RSI is above the buy threshold.
- **Sell:** the fast EMA crosses below the slow EMA and RSI is below the sell threshold.
- **Stop loss / take profit:** multiples of ATR, measured from the close of the signal bar.
- **Trailing stop (strategy only):** once price is `trail × ATR` in profit, the stop trails price at that distance.
- **Position size (strategy only):** either a fixed quantity, or sized so that hitting the stop loses `Risk %` of equity. The size is rounded down to `Quantity step`.
- **Filters:** a trading session, a long/short direction choice, and a daily loss limit that blocks new entries after the day's loss reaches the set %.

## Installation

1. In TradingView, open the **Pine Editor** at the bottom of the chart.
2. Click **Open → New blank strategy** (or **indicator**), replace the code with the contents of the `.pine` file, and click **Save**.
3. Click **Add to chart**. Change the settings with the ⚙ icon on the script's name on the chart.

## Alerts

- **Indicator:** click **Create alert**, choose `TrendEA Signals` as the condition, then pick *Buy*, *Sell* or *Any signal*.
- **Strategy:** click **Create alert** and choose `TrendEA Strategy`. The message includes the entry price, SL and TP, so you can send it to a webhook to automate trading.

## Notes

- Set **Quantity step** to your market: `1` for stocks and futures, `0.01` for forex lots, or a smaller value for crypto.
- Commission (0.05%) and slippage (2 ticks) are set in the `strategy()` header. Change them to match your broker.
- Signals are only confirmed when the bar closes. A signal on the live bar can still disappear before the bar closes.

> Trading carries substantial risk of loss. These scripts are for educational purposes and come with no guarantee of profitability.
