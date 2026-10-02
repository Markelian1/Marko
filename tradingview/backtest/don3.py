from don2 import *
raw=load('fp_m5.csv'); days=raw.index.normalize().nunique()
TF={k:raw.resample(v).agg(AGG).dropna() for k,v in [('M15','15min'),('M30','30min'),('H1','60min')]}
rows=[]; cache={}
for tf,N,k in itertools.product(['M15','M30','H1'],[20,30,40,60,80,100,120,160,200,240],[3.0,3.5,4.0,4.5,5.0]):
    hours=N*{'M15':0.25,'M30':0.5,'H1':1}[tf]
    if hours<15 or hours>70: continue
    r=system(TF[tf],N,k); cache[(tf,N,k)]=r; s=sc(r,days)
    rows.append(dict(tf=tf,N=N,hours=hours,k=k,**s))
df=pd.DataFrame(rows); df['ret_dd']=(df.R/df.dd).round(2); pd.set_option('display.width',220)
print('share PF>=1.2 both years:',((df.pf25>=1.2)&(df.pf26>=1.2)).mean().round(2))
print(df.groupby(['tf','k'])[['pf','pf25','pf26','perWeek','ret_dd']].median().round(2).to_string())
pd.to_pickle(cache,'don3_cache.pkl'); df.to_pickle('don3.pkl')
