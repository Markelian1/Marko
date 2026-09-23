from bt import *
res=[]
for win in (6,12,24):
  for move in (100,150,250):
    for rr in (1.0,1.5,2.0,3.0):
      for maxsl in (60,120):
        for be in (0,1.0):
          for dirs in ((1,-1),(1,),(-1,)):
            tr=setup_B(win=win,move=move,rr=rr,maxsl=maxsl,be=be,dirs=dirs)
            a,b=stats(tr,0,SPLIT),stats(tr,SPLIT,N)
            res.append((a['pf'],b['pf'],a['n'],b['n'],a['net'],b['net'],win,move,rr,maxsl,be,str(dirs)))
res.sort(reverse=True)
for r in res[:20]: print("IS PF %.2f OOS PF %.2f n %d/%d net %.0f/%.0f | win=%d move=%d rr=%.1f maxsl=%d be=%.1f dirs=%s"%r)
print("OOS>1.2 & IS>1.2:", sum(1 for r in res if r[0]>1.2 and r[1]>1.2 and r[2]>=30 and r[3]>=15), "of", len(res))
