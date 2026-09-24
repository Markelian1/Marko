# Nivele SD XAUUSD (strategji për testim)

Strategji në Pine Script v5 për TradingView, e bazuar te formula e postimit "x1_xent":

```
njësia (1 SD) = lëvizja "normale" e çmimit
niveli        = P_C ± k × njësia
```

- **SELL** te `P_C + 2.6 SD`, **BUY** te `P_C − 2.6 SD`
- **SL** te 3.2 SD, **TP** te 1 SD (ose te P_C nëse TP = 0)
- Maksimum 1 tregtim në ditë, mbyllje në fund të ditës

Të gjitha vlerat ndryshohen te **Settings → Inputs**.

## Si ta vendosësh

1. TradingView → hap grafikun e arit (p.sh. `CAPITALCOM:GOLD` ose `OANDA:XAUUSD`) në **5m ose 15m**.
2. **Pine Editor** → fshi çfarë ka → ngjit kodin nga `nivele_sd_xauusd.pine` → **Save** → **Add to chart**.
3. Hap **Strategy Tester** dhe shiko: Net Profit, Percent Profitable, Profit Factor, Max Drawdown.
4. Te **Settings → Properties → Commission** vendos gjysmën e spread-it të brokerit tënd (default 0.2 $/oz për çdo anë).

## Kujdes

- Njësia "Orë × √orë" është interpretimi ynë i `4.50 × 4.8`; autori nuk e shpjegon.
- Vetëm për testim dhe demo. Nuk është këshillë financiare.
