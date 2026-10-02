import itertools, pandas as pd
from bt import *
import sys
raw=load(sys.argv[1] if len(sys.argv) > 1 else 'xau.csv')
split=raw.index[int(len(raw)*0.7)]
print('split at',split)
rows=[]
grid=dict(tf=[None,'15min'],htf=['60min','240min'],adxMin=[15,20,25,30],tp=[(1.0,2.0),(1.0,3.0),(1.5,3.0),(2.0,2.0)],
          slBuf=[0.3,0.8],moveBE=[True,False],session=[(10,23),(15,23),None],dirm=['both','long'])
keys=list(grid)
for combo in itertools.product(*grid.values()):
    k=dict(zip(keys,combo)); tp=k.pop('tp'); dm=k.pop('dirm')
    t=run(raw,tp1R=tp[0],tp2R=tp[1],longOnly=(dm=='long'),**k)
    a,b=stats(t[t.index<split]),stats(t[t.index>=split])
    rows.append(dict(tf=k['tf'] or '5min',htf=k['htf'],adx=k['adxMin'],tp=tp,slBuf=k['slBuf'],be=k['moveBE'],sess=k['session'],dir=dm,
        n_is=a['n'],pf_is=a['pf'],R_is=a['netR'],dd_is=a['maxDD'],n_os=b['n'],pf_os=b['pf'],R_os=b['netR'],dd_os=b['maxDD'],win_os=b['win']))
df=pd.DataFrame(rows); df.to_pickle('grid.pkl')
pd.set_option('display.width',250); pd.set_option('display.max_columns',30)
f=df[(df.n_is>=80)]
print(f.sort_values('pf_is',ascending=False).head(20).to_string())
