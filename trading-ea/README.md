# TrendEA — MetaTrader 5 Expert Advisor

A trend-following Expert Advisor written in MQL5.

## Strategy

- **Buy:** fast EMA crosses above slow EMA on a closed bar, and RSI is above `InpRSIBuyMin`.
- **Sell:** fast EMA crosses below slow EMA on a closed bar, and RSI is below `InpRSISellMax`.
- **Stop loss / take profit:** multiples of ATR. Set `InpTPATRMult` to 0 to trade without a take profit.
- **Trailing stop (optional):** once price is more than `InpTrailATRMult × ATR` in profit, the stop follows price at that distance.
- **Opposite signal:** closes the open position when `InpCloseOnOpposite` is on.
- The EA holds at most one position per symbol, tracked by its magic number.

## Risk controls

- Position size is either a fixed lot or sized so that hitting the stop loses `InpRiskPercent` of the balance.
- If the risk-based size falls below the broker's minimum lot, the trade is skipped rather than oversized.
- It skips entries when the spread is above `InpMaxSpreadPoints` or the time is outside the trading-hours window.
- After losing `InpMaxDailyLossPct` of the day's starting balance, it opens no new trades until the next day.

## Installation

1. In MetaTrader 5, open **File → Open Data Folder**.
2. Copy `TrendEA.mq5` into `MQL5/Experts/`.
3. Open it in MetaEditor and press **F7** to compile it.
4. Drag **TrendEA** onto a chart and enable **Algo Trading**.

## Testing

Test it in the **Strategy Tester** (Ctrl+R) with "Every tick based on real ticks" before using it live. Then run it on a demo account.
The default parameters are a starting point, not tuned values. Optimise them for each symbol and timeframe.

> Trading carries substantial risk of loss. This EA is provided for educational purposes and comes with no guarantee of profitability.
