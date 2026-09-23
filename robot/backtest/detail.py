from bt import *
from collections import defaultdict
P=dict(win=8,move=200,rr=3.0,maxsl=100,be=0)
for name,d in (("te dyja",(1,-1)),("vetem BUY",(1,)),("vetem SELL",(-1,))):
    show(name, setup_B(dirs=d,**P))
for h0,h1 in ((0,24),(9,21),(9,17),(14,21)):
    show(f"ore {h0}-{h1}", setup_B(dirs=(1,-1),h0=h0,h1=h1,**P))
tr=setup_B(dirs=(1,-1),**P)
m=defaultdict(float); n=defaultdict(int)
for i,x in tr:
    k=T[i].strftime('%Y-%m'); m[k]+=x; n[k]+=1
print("Muaj: pips (hyrje)")
for k in sorted(m): print(k, round(m[k]), n[k])
print("muaj pozitive:", sum(1 for k in m if m[k]>0), "/", len(m))
