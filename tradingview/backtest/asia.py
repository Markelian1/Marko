import itertools
from sess import *
raw=load('xau.csv'); days=raw.index.normalize().nunique()
d=raw; atr,rsi,adx=base(d); c,h,l=d.Close,d.High,d.Low; hr=d.index.hour
def asia(bbn=20,k=2.0,rlo=30,adxmax=25,hrs=(2,8),slm=1.5,maxBars=24,cooldown=0):
    mid=c.rolling(bbn).mean(); sd=c.rolling(bbn).std(); up,lo=mid+k*sd,mid-k*sd
    ins=(hr>=hrs[0])&(hr<hrs[1])&(adx<adxmax)
    buy=ins&(l<lo)&(c>lo)&(rsi<50)&(rsi.rolling(3).min()<rlo)
    sell=ins&(h>up)&(c<up)&(rsi>50)&(rsi.rolling(3).max()>100-rlo)
    sig=np.where(buy,1,np.where(sell,-1,0))
    sl=pd.Series(np.where(buy,l.rolling(3).min()-slm*0.5*atr,h.rolling(3).max()+slm*0.5*atr),index=d.index)
    return run(d,sig,sl,mid,maxBars=maxBars,exitHour=10,cooldown=cooldown)
if __name__=='__main__':
    rows=[]
    for bbn,k,rlo,am,hrs,slm in itertools.product([20,30,50],[2.0,2.2],[30,35],[20,25,30],[(1,9),(2,8),(2,9)],[1.0,1.5,2.0]):
        t=asia(bbn,k,rlo,am,hrs,slm)
        a,b,s=stats(t[t.index<'2026-01-01']),stats(t[t.index>='2026-01-01']),stats(t)
        rows.append(dict(bbn=bbn,k=k,rsi=rlo,adx=am,hrs=hrs,sl=slm,n=s['n'],pf=s['pf'],dd=s['maxDD'],pf25=a['pf'],pf26=b['pf']))
    df=pd.DataFrame(rows); pd.set_option('display.width',200)
    print('combos',len(df),' profitable both years (PF>=1.0):',((df.pf25>=1)&(df.pf26>=1)).mean().round(2),' PF>=1.1 both:',((df.pf25>=1.1)&(df.pf26>=1.1)).mean().round(2))
    print('median PF all combos',df.pf.median())
    for col in ['bbn','k','rsi','adx','hrs','sl']: print(df.groupby(col)[['pf','pf25','pf26','n']].median().round(2).T.to_string())
