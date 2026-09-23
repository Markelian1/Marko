import numpy as np, pandas as pd, itertools
from numba import njit
from bt import load, ema, rma, stats
POINT=0.01; SLIP=0.05
AGG={'Open':'first','High':'max','Low':'min','Close':'last','Spread':'mean'}

@njit(cache=True)
def sim(h,l,c,spread,atr,sig,slDist,tpR,trailK,exitL,exitS,maxBars):
    n=len(c); res=np.full(n,np.nan); tr=0; e=s=t=risk=ext=0.0; eb=-1
    for i in range(n):
        if tr!=0 and i>eb:
            r=np.nan
            if tr==1:
                if l[i]<=s: r=(s-e)/risk
                elif tpR>0 and h[i]>=t: r=tpR
            else:
                if h[i]>=s: r=(e-s)/risk
                elif tpR>0 and l[i]<=t: r=tpR
            if np.isnan(r) and ((tr==1 and exitL[i]) or (tr==-1 and exitS[i]) or (maxBars>0 and i-eb>=maxBars)):
                r=(c[i]-e)*tr/risk
            if not np.isnan(r):
                res[eb]=r-(spread[eb]*POINT+SLIP)/risk; tr=0
            elif trailK>0:
                if tr==1: ext=max(ext,h[i]); s=max(s,ext-trailK*atr[i])
                else: ext=min(ext,l[i]); s=min(s,ext+trailK*atr[i])
        if tr==0 and sig[i]!=0 and slDist[i]>0:
            tr=int(sig[i]); e=c[i]; risk=slDist[i]; s=e-tr*risk; t=e+tr*risk*tpR; eb=i; ext=c[i]
    return res

def ind(d):
    c,h,l=d.Close,d.High,d.Low
    tr=pd.concat([h-l,(h-c.shift()).abs(),(l-c.shift()).abs()],axis=1).max(axis=1)
    return rma(tr,14)

def run(d,sig,slDist,tpR=0.0,trailK=0.0,exitL=None,exitS=None,maxBars=0):
    n=len(d); z=np.zeros(n,dtype=np.bool_)
    res=sim(d.High.values,d.Low.values,d.Close.values,d.Spread.values.astype(np.float64),ind(d).values,
            np.asarray(sig,dtype=np.float64),np.nan_to_num(np.asarray(slDist,dtype=np.float64)),tpR,trailK,
            z if exitL is None else np.asarray(exitL,dtype=np.bool_),z if exitS is None else np.asarray(exitS,dtype=np.bool_),maxBars)
    m=~np.isnan(res); return pd.Series(res[m],index=d.index[m])

def score(r):
    a,b=r[r.index<'2026-01-01'],r[r.index>='2026-01-01']
    pf=lambda x:(x[x>0].sum()/-x[x<0].sum()) if (x<0).any() else np.nan
    eq=r.cumsum().values; dd=(np.maximum.accumulate(np.concatenate([[0],eq]))-np.concatenate([[0],eq])).max() if len(r) else 0
    return dict(n=len(r),pf=pf(r),pf25=pf(a),pf26=pf(b),R=r.sum(),dd=dd)

def family(name,rows,days):
    df=pd.DataFrame(rows)
    both=((df.pf25>=1.1)&(df.pf26>=1.1)).mean()
    best=df.assign(m=df[['pf25','pf26']].min(axis=1)).sort_values('m',ascending=False).iloc[0]
    print(f"{name:34s} variants={len(df):3d} trades/day(med)={df.n.median()/days:4.2f} medianPF={df.pf.median():.2f} "
          f"medPF25={df.pf25.median():.2f} medPF26={df.pf26.median():.2f} share(PF>=1.1 both)={both:.0%} | best: {best.cfg} PF={best.pf:.2f} ({best.pf25:.2f}/{best.pf26:.2f}) n={int(best.n)} DD={best.dd:.1f}")
    return df
