"""Session strategies research: Asia mean reversion, London Asian-range breakout, NY opening-range breakout."""
import numpy as np, pandas as pd
from numba import njit
from bt import load, ema, rma, stats
POINT=0.01; SLIP=0.05

@njit(cache=True)
def sim(o,h,l,c,spread,sig,sl,tp,maxBars,cooldown,exitHour,hour):
    n=len(c); res=np.full(n,np.nan); dirs=np.zeros(n)
    tr=0; e=s=t=0.0; eb=-1; last=-10**9
    for i in range(n):
        if tr!=0 and i>eb:
            r=np.nan; risk=abs(e-s)
            if tr==1:
                if l[i]<=s: r=-1.0
                elif h[i]>=t: r=(t-e)/risk
            else:
                if h[i]>=s: r=-1.0
                elif l[i]<=t: r=(e-t)/risk
            if np.isnan(r) and ((maxBars>0 and i-eb>=maxBars) or (exitHour>=0 and hour[i]==exitHour)):
                r=(c[i]-e)*tr/risk
            if not np.isnan(r):
                res[eb]=r-(spread[eb]*POINT+SLIP)/risk; tr=0
        if tr==0 and sig[i]!=0 and i-last>=cooldown:
            risk=abs(c[i]-sl[i])
            if risk>0 and (tp[i]-c[i])*sig[i]>0 and (c[i]-sl[i])*sig[i]>0:
                tr=int(sig[i]); e=c[i]; s=sl[i]; t=tp[i]; eb=i; last=i; dirs[i]=tr
    return res,dirs

def run(d,sig,sl,tp,maxBars=0,cooldown=0,exitHour=-1):
    res,dirs=sim(d.Open.values,d.High.values,d.Low.values,d.Close.values,d.Spread.values.astype(np.float64),
                 sig.astype(np.float64),np.nan_to_num(sl.values),np.nan_to_num(tp.values),maxBars,cooldown,exitHour,d.index.hour.values)
    m=~np.isnan(res); return pd.DataFrame({'R':res[m],'dir':dirs[m]},index=d.index[m])

def base(d):
    c,h,l=d.Close,d.High,d.Low
    tr=pd.concat([h-l,(h-c.shift()).abs(),(l-c.shift()).abs()],axis=1).max(axis=1)
    atr=rma(tr,14); delta=c.diff()
    rsi=100-100/(1+rma(delta.clip(lower=0),14)/rma((-delta).clip(lower=0),14))
    upm,dnm=h.diff(),-l.diff()
    plus=pd.Series(np.where((upm>dnm)&(upm>0),upm,0.0),index=d.index); minus=pd.Series(np.where((dnm>upm)&(dnm>0),dnm,0.0),index=d.index)
    dip,dim=100*rma(plus,14)/atr,100*rma(minus,14)/atr; adx=rma(100*(dip-dim).abs()/(dip+dim),14)
    return atr,rsi,adx

def show(name,t,days):
    a,b,s=stats(t[t.index<'2026-01-01']),stats(t[t.index>='2026-01-01']),stats(t)
    ok='OK ' if a['pf']>=1.1 and b['pf']>=1.1 and s['n']>=80 else '   '
    print(f"{ok}{name:55s} /day={s['n']/days:4.2f} n={s['n']:4d} win={s['win']:5.1f} PF={s['pf']:.2f} R={s['netR']:6.1f} DD={s['maxDD']:5.1f} | PF25={a['pf']:.2f} PF26={b['pf']:.2f}")
    return s
