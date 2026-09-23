# TrendEA for TradingView (Pine Script v6)

This folder has two scripts. Both use the same logic as the MetaTrader 5 EA in `../trading-ea/`.

| File | Type | Use it for |
|------|------|------------|
| `TrendEA_Strategy.pine` | `strategy()` | Backtesting in the **Strategy Tester** (net profit, drawdown, list of trades) and strategy alerts |
| `TrendEA_Indicator.pine` | `indicator()` | Signals on the chart, SL/TP guide lines, a status panel and alerts you can pick from the alert menu |

## Logic

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
