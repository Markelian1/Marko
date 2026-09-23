from bt import *
res=[]
for move in (200,250):
  for conf in (0,1,2):
    for tpm,rr,fib in (('rr',2.0,0),('rr',3.0,0),('fib',0,0.382),('fib',0,0.5),('fib',0,0.618),('min',3.0,0.5),('min',3.0,0.618)):
      for minrr in (0.5,1.0,1.5):
        if tpm=='rr' and minrr!=1.0: continue
        tr=setup_C(move=move,conf=conf,tpm=tpm,rr=rr or 3.0,fib=fib or 0.5,minrr=minrr)
        a,b,al=stats(tr,0,SPLIT),stats(tr,SPLIT,N),stats(tr,0,N)
        res.append((round(min(a['pf'],b['pf']),2),a['pf'],b['pf'],a['n'],b['n'],al['net'],al['dd'],al['wr'],move,conf,tpm,rr,fib,minrr))
res.sort(reverse=True)
for r in res[:25]: print("minPF %.2f IS %.2f OOS %.2f n %d/%d net %.0f dd %.0f wr %.0f | move=%d conf=%d tp=%s rr=%.1f fib=%.3f minrr=%.1f"%r)
