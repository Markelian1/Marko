import itertools
from lt import *
d1=load('d1.csv'); c=d1.Close; h=d1.High; l=d1.Low
tr=pd.concat([h-l,(h-c.shift()).abs(),(l-c.shift()).abs()],axis=1).max(axis=1); atrD=rma(tr,14)
up_,dn_=h.diff(),-l.diff()
pdm=pd.Series(np.where((up_>dn_)&(up_>0),up_,0.),index=d1.index); mdm=pd.Series(np.where((dn_>up_)&(dn_>0),dn_,0.),index=d1.index)
dip,dim=100*rma(pdm,14)/atrD,100*rma(mdm,14)/atrD; adxD=rma(100*(dip-dim).abs()/(dip+dim),14)
erD=(c-c.shift(20)).abs()/c.diff().abs().rolling(20).sum()
e50=ema(c,50)
# map previous completed day's value to each H1 bar
key=h1.index.normalize()
def m(s): return pd.Series(s.shift(1).reindex(key).values,index=h1.index).ffill()
ADX,ER,UPD=m(adxD),m(erD),m(c>e50).astype(bool)
atrH=ATR; atrRatio=atrH/atrH.rolling(24*120).mean()
F={'none':None,
   'D1 ADX>20':(ADX>20,ADX>20),'D1 ADX>25':(ADX>25,ADX>25),
   'D1 ER>0.3':(ER>0.3,ER>0.3),'D1 ER>0.4':(ER>0.4,ER>0.4),
   'D1 EMA50 side':(UPD,~UPD),
   'ATR ratio>1':(atrRatio>1,atrRatio>1),'ATR ratio>1.2':(atrRatio>1.2,atrRatio>1.2)}
rows=[]
for (fn,f),N,k in itertools.product(F.items(),[20,40,60,100],[2.0,3.0,4.0]):
    r=donch(N=N,k=k,extra=f); s=summ(r); y=yearly(r)
    rows.append(dict(filter=fn,N=N,k=k,**s,**{f'R{yr}':v for yr,v in y.R.items()}))
df=pd.DataFrame(rows); df.to_pickle('ltgrid.pkl'); pd.set_option('display.width',250)
print(df.groupby('filter')[['pf','R','dd','yearsPos']].median().round(2).sort_values('yearsPos',ascending=False).to_string())
print(df.sort_values(['yearsPos','pf'],ascending=False).head(15).to_string())
