# TrendEA — MetaTrader 5 Expert Advisors

## TrendEA_Pro.mq5 (recommended)

This EA uses the same trend-pullback logic as the TradingView "TrendEA Pro" scripts. Its defaults are the settings that held up on the XAUUSD backtest (see `../tradingview/backtest/RESULTS.md`).

- **Timeframes:** it trades on M15 and filters by the H1 trend.
- **Filters:**
  - The EMAs are in trend order: 21 > 50 > 200 for buys, the reverse for sells.
  - The H1 close is on the correct side of the H1 EMA 50.
  - ADX (Wilder) is at least 20 and DI+/DI− agree with the direction.
  - Price pulled back to the fast EMA and a confirmation candle closed.
  - RSI is in range and volatility (ATR) is not too low.
- **Session:** 15:00–23:00 **server time**. On a UTC+3 broker this is 12:00–20:00 UTC. Adjust it for your broker.
- **Exits:** each trade opens as two half positions. The first closes at TP1 (1R). The second targets TP2 (3R), and its stop moves to breakeven once price reaches TP1. The SL sits beyond the recent swing plus 0.8 × ATR.
- **Risk:**
  - Each trade risks 1% of the balance.
  - Only one trade is open at a time, with a 10-bar cooldown between signals.
  - It stops opening trades for the day after a 3% daily loss.
  - It skips trades when the spread is above the limit.
- **Magic numbers:** the TP2 leg uses `Magic + 1`.

Test it in the Strategy Tester on XAUUSD M15 with "Every tick based on real ticks", then forward-test it on a demo account.

## TrendEA.mq5 (basic, not recommended)

This is the original EMA crossover EA. On the XAUUSD history it had no edge.

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
