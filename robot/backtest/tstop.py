from bt import *
P=dict(win=8,move=200,maxsl=100,be=0,dirs=(1,-1))
show("B rr3 (baza)", setup_B(rr=3.0,**P))
show("C conf0 rr3 (duhet ~baza)", setup_C(conf=0,tpm='rr',rr=3.0,wait=0))
for rr in (3.0,4.0,5.0):
  for mb in (12,24,48,96):
    show(f"B rr{rr} mbyll pas {mb} qirinjve", setup_B(rr=rr,maxbars=mb,**P))
