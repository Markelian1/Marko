from bt import *
show3("v1.10 (TP 5R, 2 ore)", setup_D())
print("-- TP 5R por jo me larg se X pips --")
for m in (60,80,100,120,150,200):
    show3(f"TP max {m} pips", setup_D(maxtp=m))
print("-- TP fiks X pips --")
for f in (60,80,100,120,150):
    show3(f"TP fiks {f} pips", setup_D(fixtp=f))
print("-- TP fiks, pa mbyllje me kohe --")
for f in (80,100,120):
    show3(f"TP fiks {f} pips, pa kohe", setup_D(fixtp=f, maxbars=0))
