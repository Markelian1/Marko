from strat import *
raw=load('fp_m5.csv'); days=raw.index.normalize().nunique()
TF={'M15':raw.resample('15min').agg(AGG).dropna(),'H1':raw.resample('60min').agg(AGG).dropna()}
res={}
# 1 Donchian breakout with chandelier trail
rows=[]
for tf,N,k,f in itertools.product(['M15','H1'],[20,40,55],[2.0,3.0,4.0],[True,False]):
    d=TF[tf]; c,h,l=d.Close,d.High,d.Low; atr=ind(d)
    up=c>h.shift().rolling(N).max(); dn=c<l.shift().rolling(N).min()
    if f: e200=ema(c,200); up&=c>e200; dn&=c<e200
    sig=np.where(up,1,np.where(dn,-1,0))
    rows.append(dict(cfg=f'{tf} N{N} k{k} ema{f}',**score(run(d,sig,k*atr,trailK=k))))
res['donchian']=family('1 Donchian breakout + trail',rows,days)
# 2 Previous-day high/low breakout
rows=[]
for tf,tpR,k,win in itertools.product(['M15','H1'],[0.0,1.5,2.0,3.0],[1.0,1.5,2.0],[(10,23),(15,23)]):
    d=TF[tf]; c,h,l=d.Close,d.High,d.Low; atr=ind(d); day=d.index.normalize()
    dh=h.groupby(day).max().shift(1).reindex(day).values; dl=l.groupby(day).min().shift(1).reindex(day).values
    hr=d.index.hour; w=(hr>=win[0])&(hr<win[1])
    up=w&(c>dh)&(c.shift()<=dh); dn=w&(c<dl)&(c.shift()>=dl)
    sig=np.where(up,1,np.where(dn,-1,0))
    rows.append(dict(cfg=f'{tf} tp{tpR} k{k} {win}',**score(run(d,sig,k*atr,tpR=tpR,trailK=(k if tpR==0 else 0)))))
res['pdhl']=family('2 Prev-day high/low breakout',rows,days)
# 3 RSI(2) pullback in trend (Connors)
rows=[]
for tf,th,trendLen,exitLen,slk in itertools.product(['M15','H1'],[5,10,15],[100,200],[5,10],[2.0,3.0]):
    d=TF[tf]; c=d.Close; atr=ind(d); delta=c.diff()
    r2=100-100/(1+rma(delta.clip(lower=0),2)/rma((-delta).clip(lower=0),2))
    et=ema(c,trendLen); ex=c.rolling(exitLen).mean()
    buy=(c>et)&(r2<th); sell=(c<et)&(r2>100-th)
    sig=np.where(buy,1,np.where(sell,-1,0))
    rows.append(dict(cfg=f'{tf} rsi2<{th} ema{trendLen} exitMA{exitLen} sl{slk}',**score(run(d,sig,slk*atr,exitL=(c>ex).values,exitS=(c<ex).values,maxBars=20))))
res['rsi2']=family('3 RSI(2) pullback (Connors)',rows,days)
# 4 Supertrend-style: EMA cross of ATR bands -> trend flip entries with trail
rows=[]
for tf,m,n in itertools.product(['M15','H1'],[2.0,3.0,4.0],[10,20]):
    d=TF[tf]; c,h,l=d.Close,d.High,d.Low; atr=ind(d); mid=(h+l)/2
    ub=(mid+m*atr).values; lb=(mid-m*atr).values; cv=c.values; st=np.zeros(len(d)); fu=ub.copy(); fl=lb.copy()
    for i in range(1,len(d)):
        fu[i]=ub[i] if (ub[i]<fu[i-1] or cv[i-1]>fu[i-1]) else fu[i-1]
        fl[i]=lb[i] if (lb[i]>fl[i-1] or cv[i-1]<fl[i-1]) else fl[i-1]
        st[i]=1 if cv[i]>fu[i-1] else (-1 if cv[i]<fl[i-1] else st[i-1])
    flip=np.r_[0,np.diff(st)]!=0
    sig=np.where(flip,st,0)
    rows.append(dict(cfg=f'{tf} mult{m}',**score(run(d,sig,m*atr,trailK=m))))
res['st']=family('4 Supertrend flip + trail',rows,days)
# 5 Inside bar breakout in trend
rows=[]
for tf,tpR,tl in itertools.product(['M15','H1'],[1.0,1.5,2.0,3.0],[50,200]):
    d=TF[tf]; c,h,l=d.Close,d.High,d.Low; atr=ind(d); et=ema(c,tl)
    ib=(h.shift()<h.shift(2))&(l.shift()>l.shift(2))
    up=ib&(c>h.shift())&(c>et); dn=ib&(c<l.shift())&(c<et)
    rng=(h.shift()-l.shift()); sld=pd.Series(np.maximum((c-l.shift()).where(up,(h.shift()-c)),0.5*atr),index=d.index)
    sig=np.where(up,1,np.where(dn,-1,0))
    rows.append(dict(cfg=f'{tf} tp{tpR} ema{tl}',**score(run(d,sig,sld,tpR=tpR,maxBars=48))))
res['ib']=family('5 Inside-bar breakout in trend',rows,days)
pd.to_pickle(res,'strat_res.pkl')
