from bt import *
res=[]
for win in (4,6,8):
  for move in (200,250,300,350):
    for rr in (2.5,3.0,4.0):
      for maxsl in (100,150,200):
        tr=setup_B(win=win,move=move,rr=rr,maxsl=maxsl,be=0,dirs=(1,-1))
        a,b,al=stats(tr,0,SPLIT),stats(tr,SPLIT,N),stats(tr,0,N)
        res.append((round(min(a['pf'],b['pf']),2),a['pf'],b['pf'],a['n'],b['n'],al['net'],al['dd'],win,move,rr,maxsl))
res.sort(reverse=True)
for r in res[:25]: print("minPF %.2f IS %.2f OOS %.2f n %d/%d net %.0f dd %.0f | win=%d move=%d rr=%.1f maxsl=%d"%r)
import statistics
print("share with both>1.1:", sum(1 for r in res if r[0]>1.1), "/", len(res))
