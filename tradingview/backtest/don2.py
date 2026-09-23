import numpy as np, pandas as pd, itertools
from numba import njit
from bt import load, ema, rma
AGG={'Open':'first','High':'max','Low':'min','Close':'last','Spread':'mean'}
POINT=0.01; SLIP=0.05; SWAPL=0.35; SWAPS=0.10

@njit(cache=True)
def sim(h,l,c,spread,atr,day,sig,k,tp1R,maxUnits,addStep):
    # returns per-trade R (entry-bar indexed list) ; supports partial TP1 (50%) + BE, and pyramiding units
    n=len(c); outR=[]; outT=[]; outW=[]
    dirn=0; units=0
    E=np.zeros(8); S=np.zeros(8); RK=np.zeros(8); EB=np.zeros(8,np.int64); HIT=np.zeros(8,np.bool_); REAL=np.zeros(8)
    ext=0.0; lastAdd=0.0
    for i in range(n):
        if dirn!=0:
            j=0
            while j<units:
                if EB[j]>=i: j+=1; continue
                hs = l[i]<=S[j] if dirn==1 else h[i]>=S[j]
                if (not HIT[j]) and tp1R>0:
                    h1 = h[i]>=E[j]+RK[j]*tp1R if dirn==1 else l[i]<=E[j]-RK[j]*tp1R
                    if hs:
                        r=-1.0
                    elif h1:
                        HIT[j]=True; REAL[j]=0.5*tp1R; S[j]=E[j] if (S[j]-E[j])*dirn<0 else S[j]; r=np.nan
                    else: r=np.nan
                else:
                    if hs:
                        r=(S[j]-E[j])*dirn/RK[j]
                        if HIT[j]: r=REAL[j]+0.5*r
                    else: r=np.nan
                if not np.isnan(r):
                    nights=day[i]-day[EB[j]]
                    sw=(SWAPL if dirn==1 else SWAPS)*nights/RK[j]
                    outR.append(r-(spread[EB[j]]*POINT+SLIP)/RK[j]-sw); outT.append(EB[j]); outW.append(1.0)
                    for q in range(j,units-1):
                        E[q]=E[q+1];S[q]=S[q+1];RK[q]=RK[q+1];EB[q]=EB[q+1];HIT[q]=HIT[q+1];REAL[q]=REAL[q+1]
                    units-=1
                else: j+=1
            if units==0: dirn=0
            else:
                if dirn==1: ext=max(ext,h[i])
                else: ext=min(ext,l[i])
                for j in range(units):
                    if EB[j]<i:
                        ns=ext-k*atr[i] if dirn==1 else ext+k*atr[i]
                        if dirn==1 and ns>S[j]: S[j]=ns
                        if dirn==-1 and ns<S[j]: S[j]=ns
        # entries
        if sig[i]!=0:
            if dirn==0 or (dirn==sig[i] and units<maxUnits and (c[i]-lastAdd)*dirn>=addStep*atr[i]):
                if dirn==0: dirn=int(sig[i]); ext=c[i]
                E[units]=c[i]; RK[units]=k*atr[i]; S[units]=c[i]-dirn*k*atr[i]; EB[units]=i; HIT[units]=False; REAL[units]=0.0
                units+=1; lastAdd=c[i]
    return np.array(outR),np.array(outT)

def system(d,N,k,trend=200,tp1R=0.0,maxUnits=1,addStep=1.0,mode='break'):
    c,h,l=d.Close,d.High,d.Low
    tr=pd.concat([h-l,(h-c.shift()).abs(),(l-c.shift()).abs()],axis=1).max(axis=1); atr=rma(tr,14)
    hh=h.shift().rolling(N).max(); ll=l.shift().rolling(N).min()
    if mode=='break':   # every close beyond the channel (allows adds while trending)
        up=c>hh; dn=c<ll
    else:               # first cross only
        up=(c>hh)&(c.shift()<=hh.shift()); dn=(c<ll)&(c.shift()>=ll.shift())
    if trend: e=ema(c,trend); up&=c>e; dn&=c<e
    sig=np.where(up,1,np.where(dn,-1,0)).astype(np.float64)
    day=((d.index.normalize()-d.index[0].normalize()).days).values.astype(np.int64)
    R,T=sim(h.values,l.values,c.values,d.Spread.values.astype(np.float64),atr.values,day,sig,k,tp1R,maxUnits,addStep)
    return pd.Series(R,index=d.index[T]).sort_index()

def sc(r,days):
    pf=lambda x:(x[x>0].sum()/-x[x<0].sum()) if (x<0).any() else np.nan
    a,b=r[r.index<'2026-01-01'],r[r.index>='2026-01-01']
    dd_s=r.groupby(r.index.date).sum().cumsum(); dd=(dd_s.cummax().clip(lower=0)-dd_s).max()
    return dict(n=len(r),perWeek=round(len(r)/days*5,1),win=round((r>0).mean()*100,1),pf=round(pf(r),2),pf25=round(pf(a),2),pf26=round(pf(b),2),R=round(r.sum(),1),dd=round(dd,1))
