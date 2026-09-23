import sys, os, datetime as dt
PIP = 0.10
M5 = os.environ.get("DATA", "XAUUSD_M5.csv")  # CSV i eksportuar nga MT5 (View > Symbols > Bars)

def load(path):
    T,O,H,L,C,S = [],[],[],[],[],[]
    with open(path) as f:
        next(f)
        for line in f:
            p = line.strip().split('\t')
            if len(p) < 9: continue
            T.append(dt.datetime.strptime(p[0]+' '+p[1], '%Y.%m.%d %H:%M:%S'))
            O.append(float(p[2])); H.append(float(p[3])); L.append(float(p[4])); C.append(float(p[5]))
            S.append(int(p[8]) * 0.01)
    return T,O,H,L,C,S

T,O,H,L,C,S = load(M5)
N = len(T)
SPLIT = int(N * 2 / 3)   # 2/3 per zgjedhje, 1/3 kontroll

class Book:
    """Menaxhon nje pozicion; cmimet e grafikut jane Bid, Ask = Bid + spread."""
    def __init__(self):
        self.trades = []   # (bar_hyrjes, pips)
        self.pos = None
    maxbars = 0
    def open(self, i, d, entry, sl, tp, be_r):
        risk = abs(entry - sl)
        self.pos = dict(i=i, d=d, e=entry, sl=sl, tp=tp, trig=be_r * risk if be_r > 0 else None)
        # rasti me i keq: nese i njejti bar e prek SL-ne, humbje
        if (d == 1 and L[i] <= sl) or (d == -1 and H[i] + S[i] >= sl):
            self.close(sl)
    def step(self, i):
        p = self.pos
        if p is None or i <= p['i']: return
        s = S[i]
        if self.maxbars and i - p['i'] >= self.maxbars:
            self.close(C[i] if p['d'] == 1 else C[i] + s); return
        if p['d'] == 1:   # buy: dalja me Bid
            if L[i] <= p['sl']:
                ex = min(O[i], p['sl']); self.close(ex); return
            if H[i] >= p['tp']:
                ex = max(O[i], p['tp']); self.close(ex); return
            if p['trig'] and H[i] - p['e'] >= p['trig'] and p['sl'] < p['e']:
                p['sl'] = p['e'] + PIP
        else:             # sell: dalja me Ask
            ah, al, ao = H[i] + s, L[i] + s, O[i] + s
            if ah >= p['sl']:
                ex = max(ao, p['sl']); self.close(ex); return
            if al <= p['tp']:
                ex = min(ao, p['tp']); self.close(ex); return
            if p['trig'] and p['e'] - al >= p['trig'] and p['sl'] > p['e']:
                p['sl'] = p['e'] - PIP
    def close(self, ex):
        p = self.pos
        self.trades.append((p['i'], p['d'] * (ex - p['e']) / PIP))
        self.pos = None

def stats(trades, lo, hi):
    pl = [x for i, x in trades if lo <= i < hi]
    if not pl: return dict(n=0, pf=0, net=0, wr=0, dd=0)
    g = sum(x for x in pl if x > 0); b = -sum(x for x in pl if x < 0)
    eq = peak = dd = 0
    for x in pl:
        eq += x; peak = max(peak, eq); dd = max(dd, peak - eq)
    return dict(n=len(pl), pf=g / b if b else 99, net=sum(pl), wr=100 * sum(1 for x in pl if x > 0) / len(pl), dd=dd)

def hours_ok(i, h0, h1):
    return h0 <= T[i].hour < h1

# ---------------- Setup A: LIMIT mbi majat / nen fundet e H1 ----------------
def build_h1():
    hb = []   # (start_index, end_index, high, low)
    cur = None
    for i in range(N):
        key = T[i].replace(minute=0, second=0)
        if cur is None or key != cur[0]:
            if cur: hb.append(cur)
            cur = [key, i, i, H[i], L[i]]
        else:
            cur[2] = i; cur[3] = max(cur[3], H[i]); cur[4] = min(cur[4], L[i])
    hb.append(cur)
    return hb
HB = build_h1()

def setup_A(k=3, offset=10, sl=35, rr=3.0, be=1.0, mind=30, maxd=300, h0=9, h1=21, maxday=3):
    bk = Book()
    highs, lows = [], []          # nivelet e pa-prekura
    used_day, used = None, set()
    day, dcount = None, 0
    hi_idx = 0                    # H1 i fundit i perfunduar
    # harta: per cdo bar M5, sa H1 jane perfunduar
    for i in range(N):
        # H1 te perfunduar para ketij bari
        while hi_idx < len(HB) and HB[hi_idx][2] < i:
            j = hi_idx - k   # pivot i konfirmuar me k qirinj djathtas
            if j - k >= 0:
                v = HB[j][3]
                if all(HB[j + m][3] < v for m in range(1, k + 1)) and all(HB[j - m][3] < v for m in range(1, k + 1)):
                    highs.append(v)
                v = HB[j][4]
                if all(HB[j + m][4] > v for m in range(1, k + 1)) and all(HB[j - m][4] > v for m in range(1, k + 1)):
                    lows.append(v)
            hi_idx += 1
        if T[i].date() != day:
            day, dcount, used = T[i].date(), 0, set()
        bk.step(i)
        # urdhrat e vendosur ne mbylljen e barit te meparshem
        if bk.pos is None and i > 0 and hours_ok(i, h0, h1) and dcount < maxday:
            ref = C[i - 1]
            sh = [v for v in highs if mind * PIP <= v - ref <= maxd * PIP and v not in used]
            sl_ = [v for v in lows if mind * PIP <= ref - v <= maxd * PIP and v not in used]
            lvl_s = min(sh) if sh else None
            lvl_b = max(sl_) if sl_ else None
            ps = lvl_s + offset * PIP if lvl_s else None
            pb = lvl_b - offset * PIP if lvl_b else None
            fs = ps is not None and H[i] >= ps
            fb = pb is not None and L[i] + S[i] <= pb
            if fs and not fb:
                e = max(O[i], ps)
                bk.open(i, -1, e, e + sl * PIP, e - rr * sl * PIP, be); used.add(lvl_s); dcount += 1
            elif fb and not fs:
                e = min(O[i] + S[i], pb)
                bk.open(i, 1, e, e - sl * PIP, e + rr * sl * PIP, be); used.add(lvl_b); dcount += 1
        # nivelet e kaluara hiqen
        highs = [v for v in highs if H[i] <= v]
        lows = [v for v in lows if L[i] >= v]
    return bk.trades

# ---------------- Setup B: kundra levizjes se forte (fade) ----------------
def setup_B(win=12, move=150, rr=2.0, buf=5, maxsl=80, be=1.0, h0=9, h1=21, maxday=3, dirs=(1, -1), maxbars=0):
    bk = Book(); bk.maxbars = maxbars
    day, dcount = None, 0
    for i in range(win, N - 1):
        if T[i].date() != day: day, dcount = T[i].date(), 0
        bk.step(i)
        if bk.pos is not None or not hours_ok(i, h0, h1) or dcount >= maxday: continue
        hs = H[i - win + 1:i + 1]; ls = L[i - win + 1:i + 1]
        mx, mn = max(hs), min(ls)
        imx = hs.index(mx); imn = ls.index(mn)
        # BUY: renie e forte (maja para fundit), fundi ne 2 qirinjte e fundit, qiri jeshil
        if 1 in dirs and mx - mn >= move * PIP and imx < imn and imn >= win - 2 and C[i] > O[i]:
            e = O[i + 1] + S[i + 1]; slp = mn - buf * PIP; risk = e - slp
            if 0 < risk <= maxsl * PIP:
                bk.open(i + 1, 1, e, slp, e + rr * risk, be); dcount += 1; continue
        # SELL: ngritje e forte, maja ne 2 qirinjte e fundit, qiri i kuq
        if -1 in dirs and mx - mn >= move * PIP and imn < imx and imx >= win - 2 and C[i] < O[i]:
            e = O[i + 1]; slp = mx + buf * PIP + S[i + 1]; risk = slp - e
            if 0 < risk <= maxsl * PIP:
                bk.open(i + 1, -1, e, slp, e - rr * risk, be); dcount += 1
    return bk.trades

def show(name, tr):
    a, b, al = stats(tr, 0, SPLIT), stats(tr, SPLIT, N), stats(tr, 0, N)
    print(f"{name:55s} | IS n={a['n']:4d} PF={a['pf']:.2f} net={a['net']:7.0f} | OOS n={b['n']:4d} PF={b['pf']:.2f} net={b['net']:7.0f} wr={b['wr']:4.1f}% | ALL PF={al['pf']:.2f} net={al['net']:7.0f} dd={al['dd']:.0f}")

if __name__ == '__main__':
    print(T[0], T[SPLIT], T[-1], N)

# ---------------- Setup C: si B, me konfirmim dhe TP te kthimit ----------------
def setup_C(win=8, move=200, buf=5, maxsl=100, conf=0, tpm='rr', rr=3.0, fib=0.5, minrr=1.0,
            wait=6, h0=9, h1=21, maxday=3, dirs=(1, -1)):
    """conf: 0 = qiri i kundert (si B); 1 = mbyllje mbi majen/nen fundin e qiririt te meparshem;
             2 = mbyllje mbi majen/nen fundin e qiririt qe beri ekstremin (pritet deri 'wait' qirinj)
       tpm:  'rr' = TP rr*R; 'fib' = TP ne kthimin 'fib' te levizjes; 'min' = me i afermi nga te dyja"""
    bk = Book()
    day, dcount = None, 0
    pend = None   # impuls ne pritje te konfirmimit: (dir, ext, other_end, bar_ext, expiry)
    for i in range(win, N - 1):
        if T[i].date() != day: day, dcount = T[i].date(), 0
        bk.step(i)
        hs = H[i - win + 1:i + 1]; ls = L[i - win + 1:i + 1]
        mx, mn = max(hs), min(ls)
        imx = hs.index(mx); imn = ls.index(mn)
        big = mx - mn >= move * PIP
        # impuls i ri: ekstremi ne 2 qirinjte e fundit
        if big and imx < imn and imn >= win - 2:
            if pend is None or pend[0] != 1 or mn < pend[1]:
                pend = (1, mn, mx, i - (win - 1 - imn), i + wait)
        elif big and imn < imx and imx >= win - 2:
            if pend is None or pend[0] != -1 or mx > pend[1]:
                pend = (-1, mx, mn, i - (win - 1 - imx), i + wait)
        if pend is None: continue
        d, ext, other, bext, exp = pend
        # ekstrem i ri e zgjat impulsin
        if d == 1 and L[i] < ext: pend = (1, L[i], other, i, i + wait); d, ext, bext = 1, L[i], i
        if d == -1 and H[i] > ext: pend = (-1, H[i], other, i, i + wait); d, ext, bext = -1, H[i], i
        if i > pend[4]: pend = None; continue
        if bk.pos is not None or not hours_ok(i, h0, h1) or dcount >= maxday or d not in dirs: continue
        if conf == 0:
            ok = (C[i] > O[i]) if d == 1 else (C[i] < O[i])
        elif conf == 1:
            ok = (C[i] > H[i - 1] and C[i] > O[i]) if d == 1 else (C[i] < L[i - 1] and C[i] < O[i])
        else:
            ok = (i > bext and C[i] > H[bext]) if d == 1 else (i > bext and C[i] < L[bext])
        if not ok: continue
        if d == 1:
            e = O[i + 1] + S[i + 1]; slp = ext - buf * PIP; risk = e - slp
            tp_rr = e + rr * risk; tp_f = ext + fib * (other - ext)
        else:
            e = O[i + 1]; slp = ext + buf * PIP + S[i + 1]; risk = slp - e
            tp_rr = e - rr * risk; tp_f = ext - fib * (ext - other)
        if not (0 < risk <= maxsl * PIP): continue
        tp = tp_rr if tpm == 'rr' else tp_f if tpm == 'fib' else (min(tp_rr, tp_f) if d == 1 else max(tp_rr, tp_f))
        if d * (tp - e) < minrr * risk: continue
        bk.open(i + 1, d, e, slp, tp, 0); dcount += 1; pend = None
    return bk.trades
