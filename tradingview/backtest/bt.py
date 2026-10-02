"""Backtest of the TrendEA Pro Pine logic on MT5 XAUUSD history (bars in broker server time)."""
import numpy as np
import pandas as pd
from numba import njit

POINT = 0.01
SLIP = 0.05  # extra round-trip slippage in $ on top of the recorded spread


def load(path):
    d = pd.read_csv(path)
    d["t"] = pd.to_datetime(d.DateTime, format="%Y.%m.%d %H:%M:%S")
    return d.set_index("t")[["Open", "High", "Low", "Close", "Spread"]]


def ema(x, n):
    return x.ewm(span=n, adjust=False).mean()


def rma(x, n):
    return x.ewm(alpha=1.0 / n, adjust=False).mean()


def resample_bars(d, rule):
    if rule is None:
        return d
    agg = {"Open": "first", "High": "max", "Low": "min", "Close": "last", "Spread": "mean"}
    return d.resample(rule, label="left", closed="left").agg(agg).dropna()


def indicators(d, p):
    c, h, l = d.Close, d.High, d.Low
    out = pd.DataFrame(index=d.index)
    out["fast"] = ema(c, p["fast"])
    out["slow"] = ema(c, p["slow"])
    out["base"] = ema(c, p["base"])
    tr = pd.concat([h - l, (h - c.shift()).abs(), (l - c.shift()).abs()], axis=1).max(axis=1)
    out["atr"] = rma(tr, 14)
    out["atrAvg"] = out.atr.rolling(50).mean()
    delta = c.diff()
    up, dn = rma(delta.clip(lower=0), 14), rma((-delta).clip(lower=0), 14)
    out["rsi"] = 100 - 100 / (1 + up / dn)
    upm, dnm = h.diff(), -l.diff()
    plus = np.where((upm > dnm) & (upm > 0), upm, 0.0)
    minus = np.where((dnm > upm) & (dnm > 0), dnm, 0.0)
    atr_r = rma(tr, 14)
    dip = 100 * rma(pd.Series(plus, index=d.index), 14) / atr_r
    dim = 100 * rma(pd.Series(minus, index=d.index), 14) / atr_r
    dx = 100 * (dip - dim).abs() / (dip + dim)
    out["adx"], out["dip"], out["dim"] = rma(dx, 14), dip, dim
    # HTF: last closed HTF bar's close and EMA (non-repainting)
    if p["htf"]:
        hc = d.Close.resample(p["htf"], label="left", closed="left").last().dropna()
        he = ema(hc, 50)
        key = d.index.floor(p["htf"])
        out["htfC"] = hc.shift(1).reindex(key).values
        out["htfE"] = he.shift(1).reindex(key).values
    else:
        out["htfC"], out["htfE"] = 1.0, 0.0
    return out


@njit(cache=True)
def simulate(o, h, l, c, spread, sigL, sigS, slL, slS, cooldown, tp1R, tp2R, moveBE, point, slip):
    n = len(c)
    res = np.full(n, np.nan)  # R result stored at entry bar
    direction = np.zeros(n)
    exit_bar = np.full(n, -1)
    trade = 0
    entry = sl = tp1 = tp2 = risk = 0.0
    tp1hit = False
    ebar = -1
    last = -10**9
    for i in range(n):
        if trade != 0 and i > ebar:
            if trade == 1:
                hs, h1, h2 = l[i] <= sl, h[i] >= tp1, h[i] >= tp2
            else:
                hs, h1, h2 = h[i] >= sl, l[i] <= tp1, l[i] <= tp2
            r = np.nan
            if not tp1hit:
                if hs:
                    r = -1.0
                elif h2:
                    r = 0.5 * tp1R + 0.5 * tp2R
                elif h1:
                    tp1hit = True
                    if moveBE:
                        sl = entry
            else:
                if hs:
                    r = 0.5 * tp1R + 0.5 * (sl - entry) * trade / risk
                elif h2:
                    r = 0.5 * tp1R + 0.5 * tp2R
            if not np.isnan(r):
                cost = (spread[ebar] * point + slip) / risk
                res[ebar] = r - cost
                exit_bar[ebar] = i
                trade = 0
        if trade == 0 and i - last >= cooldown:
            if sigL[i] or sigS[i]:
                trade = 1 if sigL[i] else -1
                entry = c[i]
                sl = slL[i] if trade == 1 else slS[i]
                risk = abs(entry - sl)
                tp1 = entry + trade * risk * tp1R
                tp2 = entry + trade * risk * tp2R
                tp1hit = False
                ebar = i
                last = i
                direction[i] = trade
    return res, direction, exit_bar


DEFAULT = dict(tf=None, fast=21, slow=50, base=200, htf="15min", useAdx=True, adxMin=20.0,
               rsiMaxL=70.0, rsiMinS=30.0, pb=5, useVol=True, volRatio=0.8, cooldown=10,
               swing=5, slBuf=0.3, minSl=0.5, maxSl=3.0, tp1R=1.0, tp2R=2.0, moveBE=True,
               session=(10, 23), longOnly=False, shortOnly=False)

_cache = {}


def run(raw, **kw):
    p = dict(DEFAULT, **kw)
    d = resample_bars(raw, p["tf"])
    key = (p["tf"], p["fast"], p["slow"], p["base"], p["htf"])
    if key not in _cache:
        _cache[key] = indicators(d, p)
    ind = _cache[key]
    c, h, l = d.Close, d.High, d.Low
    hour = d.index.hour
    s0, s1 = p["session"] if p["session"] else (0, 24)
    inSess = (hour >= s0) & (hour < s1)
    volOk = (ind.atr >= ind.atrAvg * p["volRatio"]) if p["useVol"] else True
    adxL = ((ind.adx >= p["adxMin"]) & (ind.dip > ind.dim)) if p["useAdx"] else True
    adxS = ((ind.adx >= p["adxMin"]) & (ind.dim > ind.dip)) if p["useAdx"] else True
    bull = (ind.fast > ind.slow) & (ind.slow > ind.base) & (c > ind.base)
    bear = (ind.fast < ind.slow) & (ind.slow < ind.base) & (c < ind.base)
    htfB, htfS = ind.htfC > ind.htfE, ind.htfC < ind.htfE
    pb = p["pb"]
    pbL = (l.rolling(pb).min() <= ind.fast) & (c.rolling(pb).min() > ind.slow)
    pbS = (h.rolling(pb).max() >= ind.fast) & (c.rolling(pb).max() < ind.slow)
    trgL = (c > ind.fast) & (c > d.Open) & (c > h.shift())
    trgS = (c < ind.fast) & (c < d.Open) & (c < l.shift())
    rsiL = (ind.rsi > 50) & (ind.rsi < p["rsiMaxL"])
    rsiS = (ind.rsi < 50) & (ind.rsi > p["rsiMinS"])
    atr = ind.atr
    slL = np.minimum(l.rolling(p["swing"]).min() - atr * p["slBuf"], c - atr * p["minSl"])
    slS = np.maximum(h.rolling(p["swing"]).max() + atr * p["slBuf"], c + atr * p["minSl"])
    okL = (c - slL) <= atr * p["maxSl"]
    okS = (slS - c) <= atr * p["maxSl"]
    sigL = bull & htfB & adxL & volOk & inSess & pbL & trgL & rsiL & okL
    sigS = bear & htfS & adxS & volOk & inSess & pbS & trgS & rsiS & okS & ~sigL
    if p["shortOnly"]:
        sigL[:] = False
    if p["longOnly"]:
        sigS[:] = False
    res, dirn, xb = simulate(d.Open.values, h.values, l.values, c.values, d.Spread.values.astype(np.float64),
                             sigL.fillna(False).values, sigS.fillna(False).values,
                             slL.values, slS.values, p["cooldown"], p["tp1R"], p["tp2R"], p["moveBE"], POINT, SLIP)
    m = ~np.isnan(res)
    return pd.DataFrame({"R": res[m], "dir": dirn[m]}, index=d.index[m])


def stats(t):
    if len(t) == 0:
        return dict(n=0, win=0, avgR=0, netR=0, pf=0, maxDD=0)
    r = t.R.values
    eq = np.cumsum(r)
    dd = (np.maximum.accumulate(np.concatenate([[0], eq])) - np.concatenate([[0], eq])).max()
    gw, gl = r[r > 0].sum(), -r[r < 0].sum()
    return dict(n=len(r), win=round((r > 0).mean() * 100, 1), avgR=round(r.mean(), 3),
                netR=round(r.sum(), 1), pf=round(gw / gl, 2) if gl > 0 else np.inf, maxDD=round(dd, 1))
