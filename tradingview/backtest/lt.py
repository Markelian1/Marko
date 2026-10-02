"""Long-term (2020-2026) research on H1 with yearly breakdown."""
import numpy as np, pandas as pd
from tpbe import sim
from bt import load, ema, rma
h1=load('h1.csv')
def prep(d):
    c,h,l=d.Close,d.High,d.Low
    tr=pd.concat([h-l,(h-c.shift()).abs(),(l-c.shift()).abs()],axis=1).max(axis=1)
    return rma(tr,14)
ATR=prep(h1); DAY=((h1.index.normalize()-h1.index[0].normalize()).days).values.astype(np.int64)
def donch(N=40,k=3.0,trend=200,tpR=4.0,beR=1.0,extra=None,d=h1,atr=None,day=None):
    atr=ATR if atr is None else atr; day=DAY if day is None else day
    c,h,l=d.Close,d.High,d.Low
    up=c>h.shift().rolling(N).max(); dn=c<l.shift().rolling(N).min()
    if trend: e=ema(c,trend); up&=c>e; dn&=c<e
    if extra is not None: up&=extra[0]; dn&=extra[1]
    sig=np.where(up,1,np.where(dn,-1,0)).astype(float)
    R,T=sim(h.values,l.values,c.values,d.Spread.values.astype(float),atr.values,day,sig,k,float(tpR),beR,0.1)
    return pd.Series(R,index=d.index[T]).sort_index()
def pf(x): return round(x[x>0].sum()/-x[x<0].sum(),2) if (x<0).any() else np.nan
def yearly(r):
    g=r.groupby(r.index.year); return pd.DataFrame({'n':g.size(),'R':g.sum().round(1),'pf':g.apply(pf)})
def summ(r):
    y=yearly(r); eq=r.cumsum(); dd=(eq.cummax().clip(lower=0)-eq).max()
    return dict(n=len(r),pf=pf(r),R=round(r.sum(),1),dd=round(dd,1),yearsPos=int((y.R>0).sum()),years=len(y),worstYearR=y.R.min())
