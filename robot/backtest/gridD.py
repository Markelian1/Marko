from bt import *
show3("v1.10 (move 200, sl100)", setup_D())
print("-- pragu sipas volatilitetit --")
for k in (4,5,6,7,8,10):
    show3(f"katr={k} maxsl100", setup_D(katr=k))
for k in (5,6,7,8):
    for sa in (3,4):
        show3(f"katr={k} slatr={sa}", setup_D(katr=k, slatr=sa))
print("-- filtri i trendit --")
for tr_ in (1,-1):
    for tl in (600,2400):
        show3(f"trend={tr_} ema={tl}", setup_D(trend=tr_, tlen=tl))
print("-- pauza pas hyrjes --")
for cd in (6,12,24):
    show3(f"cooldown={cd}", setup_D(cooldown=cd))
