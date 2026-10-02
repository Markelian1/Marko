import numpy as np, pandas as pd, itertools
from numba import njit
from don2 import load, ema, rma, AGG, sc
@njit(cache=True)
def sim(h,l,c,spread,atr,day,sig,k,tpR,beR,beLock):
    n=len(c); R=[]; T=[]; tr=0; e=s=risk=ext=t=0.0; eb=-1; be=False
    for i in range(n):
        if tr!=0 and i>eb:
            r=np.nan
            if tr==1:
                if l[i]<=s: r=(s-e)/risk
                elif tpR>0 and h[i]>=t: r=tpR
            else:
                if h[i]>=s: r=(e-s)/risk
                elif tpR>0 and l[i]<=t: r=tpR
            if not np.isnan(r):
                sw=(0.35 if tr==1 else 0.10)*(day[i]-day[eb])/risk
                R.append(r-(spread[eb]*0.01+0.05)/risk-sw); T.append(eb); tr=0
            else:
                if tr==1: ext=max(ext,h[i])
                else: ext=min(ext,l[i])
                if beR>0 and not be and (ext-e)*tr>=beR*risk:
                    be=True; lk=e+tr*beLock*risk
                    if (lk-s)*tr>0: s=lk
                ns=ext-tr*k*atr[i]
                if (ns-s)*tr>0: s=ns
        if tr==0 and sig[i]!=0:
            tr=int(sig[i]); e=c[i]; risk=k*atr[i]; s=e-tr*risk; t=e+tr*risk*tpR; ext=e; eb=i; be=False
    return np.array(R),np.array(T)
if __name__=="__main__":
    raw=load('fp_m5.csv'); days=raw.index.normalize().nunique(); d=raw.resample('60min').agg(AGG).dropna()
    c,h,l=d.Close,d.High,d.Low
    tr_=pd.concat([h-l,(h-c.shift()).abs(),(l-c.shift()).abs()],axis=1).max(axis=1); atr=rma(tr_,14); e200=ema(c,200)
    up=(c>h.shift().rolling(40).max())&(c>e200); dn=(c<l.shift().rolling(40).min())&(c<e200)
    sig=np.where(up,1,np.where(dn,-1,0)).astype(float); day=((d.index.normalize()-d.index[0].normalize()).days).values.astype(np.int64)
    rows=[]
    for tpR,beR in itertools.product([0,2,3,4,5,6],[0,1.0,1.5,2.0,3.0]):
        if tpR and beR>=tpR: continue
        R,T=sim(h.values,l.values,c.values,d.Spread.values.astype(float),atr.values,day,sig,3.0,float(tpR),beR,0.1)
        s=sc(pd.Series(R,index=d.index[T]).sort_index(),days); rows.append(dict(TP=tpR or 'none',BE=beR or 'off',**s))
    df=pd.DataFrame(rows); pd.set_option('display.width',200); print(df.to_string())
