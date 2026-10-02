from don2 import *
raw=load('fp_m5.csv'); days=raw.index.normalize().nunique()
TF={k:raw.resample(v).agg(AGG).dropna() for k,v in [('M15','15min'),('M30','30min'),('H1','60min')]}
def P(name,r): s=sc(r,days); print(f"{name:52s} {s}"); return s
print('--- baseline (current DonchianEA)')
P('H1 N40 k3',system(TF['H1'],40,3.0,mode='break'))
print('--- A: partial TP1 50% + BE (accuracy)')
for t in [0.75,1.0,1.5]: P(f'H1 N40 k3 tp1={t}',system(TF['H1'],40,3.0,tp1R=t))
print('--- B: faster timeframes (channel scaled in hours)')
for tf,N in [('M30',80),('M30',60),('M15',160),('M15',120)]:
    for k in [3.0,4.0]: P(f'{tf} N{N} k{k}',system(TF[tf],N,k))
print('--- C: pyramiding (adds each +1ATR new breakout, max units)')
for mu,st in [(2,1.0),(3,1.0),(3,0.5)]: P(f'H1 N40 k3 units{mu} step{st}',system(TF['H1'],40,3.0,maxUnits=mu,addStep=st))
print('--- D: multi-system (independent 20/40/55 on H1 + M30 80)')
parts={ 'H1-20':system(TF['H1'],20,3.0),'H1-40':system(TF['H1'],40,3.0),'H1-55':system(TF['H1'],55,3.0),'M30-80':system(TF['M30'],80,3.0)}
for combo in [['H1-20','H1-40','H1-55'],['H1-20','H1-40','H1-55','M30-80']]:
    P('+'.join(combo),pd.concat([parts[x] for x in combo]).sort_index())
