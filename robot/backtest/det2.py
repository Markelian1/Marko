from bt import *
from collections import defaultdict
for rr,mb in ((3.0,0),(5.0,24)):
    tr=setup_B(win=8,move=200,rr=rr,maxsl=100,be=0,dirs=(1,-1),maxbars=mb)
    m=defaultdict(float)
    for i,x in tr: m[T[i].strftime('%Y-%m')]+=x
    print(f"rr{rr} mb{mb}:", " ".join(f"{k[2:]}:{round(v)}" for k,v in sorted(m.items())), "| pozitive", sum(1 for v in m.values() if v>0),"/",len(m))
