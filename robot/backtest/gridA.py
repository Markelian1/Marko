from bt import *
res=[]
for k in (2,3,5):
  for off in (0,10,25,50):
    for sl in (35,60,100):
      for rr in (1.0,1.5,2.0,3.0):
        for be in (0,1.0):
          tr=setup_A(k=k,offset=off,sl=sl,rr=rr,be=be)
          a,b=stats(tr,0,SPLIT),stats(tr,SPLIT,N)
          res.append((a['pf'],b['pf'],a['n'],b['n'],a['net'],b['net'],k,off,sl,rr,be))
res.sort(reverse=True)
for r in res[:15]: print("IS PF %.2f OOS PF %.2f n %d/%d net %.0f/%.0f | k=%d off=%d sl=%d rr=%.1f be=%.1f"%r)
print("OOS>1.2 & IS>1.2:", sum(1 for r in res if r[0]>1.2 and r[1]>1.2), "of", len(res))
