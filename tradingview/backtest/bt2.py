"""Structural variants of TrendEA Pro, on top of bt.py indicators."""
import numpy as np, pandas as pd
from numba import njit
import bt
from bt import load, resample_bars, indicators, ema, stats

@njit(cache=True)
def sim2(o, h, l, c, spread, atr, sigL, sigS, slL, slS, trgHi, trgLo, cooldown, tp1R, tp2R,
         trailK, maxBars, stopEntry, stopValid, point, slip):
    n = len(c)
    res = np.full(n, np.nan); dirs = np.zeros(n)
    trade = 0; entry = sl = tp1 = tp2 = risk = 0.0; tp1hit = False; ebar = -1; last = -10**9
    pend = 0; pLevel = 0.0; pSl = 0.0; pBar = -1
    ext = 0.0
    for i in range(n):
        # pending stop entry
        if pend != 0 and trade == 0:
            if i - pBar > stopValid:
                pend = 0
            else:
                hit = h[i] >= pLevel if pend == 1 else l[i] <= pLevel
                # cancel if stop level would be hit first (conservative: invalid if bar crosses SL too)
                if hit:
                    trade = pend; entry = max(pLevel, o[i]) if pend == 1 else min(pLevel, o[i])
                    sl = pSl; risk = abs(entry - sl)
                    if risk <= 0:
                        trade = 0; pend = 0
                    else:
                        tp1 = entry + trade * risk * tp1R; tp2 = entry + trade * risk * tp2R
                        tp1hit = False; ebar = i; dirs[i] = trade; pend = 0
                        ext = h[i] if trade == 1 else l[i]
                        # same-bar stop check (worst case)
                        if (trade == 1 and l[i] <= sl) or (trade == -1 and h[i] >= sl):
                            res[ebar] = -1.0 - (spread[ebar] * point + slip) / risk
                            trade = 0
                        continue
        if trade != 0 and i > ebar:
            if trade == 1:
                hs, h1, h2 = l[i] <= sl, h[i] >= tp1, (tp2R > 0 and h[i] >= tp2)
            else:
                hs, h1, h2 = h[i] >= sl, l[i] <= tp1, (tp2R > 0 and l[i] <= tp2)
            r = np.nan
            if not tp1hit:
                if hs: r = -1.0
                elif h2: r = 0.5 * tp1R + 0.5 * tp2R
                elif h1:
                    tp1hit = True; sl = entry
            else:
                if hs: r = 0.5 * tp1R + 0.5 * (sl - entry) * trade / risk
                elif h2: r = 0.5 * tp1R + 0.5 * tp2R
            if np.isnan(r) and maxBars > 0 and i - ebar >= maxBars:
                r = (0.5 * tp1R if tp1hit else 0.0) + (0.5 if tp1hit else 1.0) * (c[i] - entry) * trade / risk
            if not np.isnan(r):
                res[ebar] = r - (spread[ebar] * point + slip) / risk
                trade = 0
            else:
                # chandelier trail after TP1 (updated at bar close, applies next bar)
                if tp1hit and trailK > 0:
                    if trade == 1:
                        ext = max(ext, h[i]); sl = max(sl, ext - trailK * atr[i])
                    else:
                        ext = min(ext, l[i]); sl = min(sl, ext + trailK * atr[i])
                elif trade == 1: ext = max(ext, h[i])
                else: ext = min(ext, l[i])
        if trade == 0 and pend == 0 and i - last >= cooldown and (sigL[i] or sigS[i]):
            d = 1 if sigL[i] else -1
            last = i
            if stopEntry:
                pend = d; pBar = i
                pLevel = trgHi[i] + 0.1 * atr[i] if d == 1 else trgLo[i] - 0.1 * atr[i]
                pSl = slL[i] if d == 1 else slS[i]
            else:
                trade = d; entry = c[i]; sl = slL[i] if d == 1 else slS[i]; risk = abs(entry - sl)
                tp1 = entry + d * risk * tp1R; tp2 = entry + d * risk * tp2R
                tp1hit = False; ebar = i; dirs[i] = d
                ext = h[i] if d == 1 else l[i]
    m = ~np.isnan(res)
    return res, dirs

BASE = dict(tf='15min', htf='60min', adxMin=20.0, tp1R=1.0, tp2R=3.0, slBuf=0.8, session=(15, 23),
            fast=21, slow=50, base=200, rsiMaxL=70.0, rsiMinS=30.0, pb=5, volRatio=0.8, cooldown=10,
            swing=5, minSl=0.5, maxSl=3.0,
            trailK=0.0, maxBars=0, stopEntry=False, stopValid=3, htf2=None, maxVol=0.0, slopeBars=0)
_c = {}
def run2(raw, **kw):
    p = dict(BASE, **kw)
    d = resample_bars(raw, p['tf'])
    key = (p['tf'], p['htf'], p['fast'], p['slow'], p['base'])
    if key not in _c:
        _c[key] = indicators(d, dict(p))
    ind = _c[key]
    c, h, l = d.Close, d.High, d.Low
    hour = d.index.hour
    inS = (hour >= p['session'][0]) & (hour < p['session'][1])
    volOk = ind.atr >= ind.atrAvg * p['volRatio']
    if p['maxVol'] > 0:
        volOk &= ind.atr <= ind.atrAvg * p['maxVol']
    adxL = (ind.adx >= p['adxMin']) & (ind.dip > ind.dim)
    adxS = (ind.adx >= p['adxMin']) & (ind.dim > ind.dip)
    bull = (ind.fast > ind.slow) & (ind.slow > ind.base) & (c > ind.base)
    bear = (ind.fast < ind.slow) & (ind.slow < ind.base) & (c < ind.base)
    hB, hS = ind.htfC > ind.htfE, ind.htfC < ind.htfE
    if p['htf2']:
        hc = d.Close.resample(p['htf2'], label='left', closed='left').last().dropna()
        he = ema(hc, 50); key2 = d.index.floor(p['htf2'])
        c2 = pd.Series(hc.shift(1).reindex(key2).values, index=d.index)
        e2 = pd.Series(he.shift(1).reindex(key2).values, index=d.index)
        hB &= c2 > e2; hS &= c2 < e2
    if p['slopeBars'] > 0:
        hB &= ind.slow > ind.slow.shift(p['slopeBars']); hS &= ind.slow < ind.slow.shift(p['slopeBars'])
    pb = p['pb']
    pbL = (l.rolling(pb).min() <= ind.fast) & (c.rolling(pb).min() > ind.slow)
    pbS = (h.rolling(pb).max() >= ind.fast) & (c.rolling(pb).max() < ind.slow)
    trgL = (c > ind.fast) & (c > d.Open) & (c > h.shift())
    trgS = (c < ind.fast) & (c < d.Open) & (c < l.shift())
    rsiL = (ind.rsi > 50) & (ind.rsi < p['rsiMaxL']); rsiS = (ind.rsi < 50) & (ind.rsi > p['rsiMinS'])
    atr = ind.atr
    slL = np.minimum(l.rolling(p['swing']).min() - atr * p['slBuf'], c - atr * p['minSl'])
    slS = np.maximum(h.rolling(p['swing']).max() + atr * p['slBuf'], c + atr * p['minSl'])
    sigL = bull & hB & adxL & volOk & inS & pbL & trgL & rsiL & ((c - slL) <= atr * p['maxSl'])
    sigS = bear & hS & adxS & volOk & inS & pbS & trgS & rsiS & ((slS - c) <= atr * p['maxSl']) & ~sigL
    res, dirs = sim2(d.Open.values, h.values, l.values, c.values, d.Spread.values.astype(np.float64), atr.values,
                     sigL.fillna(False).values, sigS.fillna(False).values, slL.values, slS.values, h.values, l.values,
                     p['cooldown'], p['tp1R'], p['tp2R'], p['trailK'], p['maxBars'], p['stopEntry'], p['stopValid'],
                     bt.POINT, bt.SLIP)
    m = ~np.isnan(res)
    return pd.DataFrame({'R': res[m], 'dir': dirs[m]}, index=d.index[m])

def report(raw, label, **kw):
    t = run2(raw, **kw)
    a, b = stats(t[t.index < '2026-01-01']), stats(t[t.index >= '2026-01-01'])
    al = stats(t)
    print(f"{label:38s} ALL n={al['n']:3d} pf={al['pf']:.2f} R={al['netR']:6.1f} dd={al['maxDD']:5.1f} | 2025 pf={a['pf']:.2f} R={a['netR']:5.1f} | 2026 pf={b['pf']:.2f} R={b['netR']:5.1f} dd={b['maxDD']:4.1f}")
    return t
