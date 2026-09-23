from sess import *
raw=load('xau.csv'); days=raw.index.normalize().nunique()
agg={'Open':'first','High':'max','Low':'min','Close':'last','Spread':'mean'}
for tfname,d in [('M5',raw),('M15',raw.resample('15min').agg(agg).dropna())]:
    atr,rsi,adx=base(d); c,h,l=d.Close,d.High,d.Low; hr=d.index.hour
    print('=====',tfname,'Asia mean reversion (Bollinger + RSI, low ADX)')
    for bbn,k,rlo,adxmax,hrs in [(20,2.0,30,25,(1,9)),(20,2.0,25,25,(1,9)),(20,2.5,30,30,(1,9)),(20,2.0,30,20,(1,9)),(20,2.0,30,25,(2,8)),(50,2.0,30,25,(1,9))]:
        mid=c.rolling(bbn).mean(); sd=c.rolling(bbn).std(); up,lo=mid+k*sd,mid-k*sd
        ins=(hr>=hrs[0])&(hr<hrs[1])&(adx<adxmax)
        # fade: close back inside after piercing band
        buy=ins&(l<lo)&(c>lo)&(rsi<50)&(rsi.rolling(3).min()<rlo)
        sell=ins&(h>up)&(c<up)&(rsi>50)&(rsi.rolling(3).max()>100-rlo)
        sig=np.where(buy,1,np.where(sell,-1,0))
        for slm in [1.0,1.5]:
            sl=pd.Series(np.where(buy,l.rolling(3).min()-slm*0.5*atr,h.rolling(3).max()+slm*0.5*atr),index=d.index)
            show(f'BB{bbn},{k} rsi{rlo} adx<{adxmax} h{hrs} sl{slm} tp=mid',run(d,sig,sl,mid,maxBars=24 if tfname=="M5" else 8,exitHour=10),days)
    print('=====',tfname,'London breakout of Asian range')
    dd=d.index.normalize()
    asia=(hr>=1)&(hr<10)
    ah=h.where(asia).groupby(dd).transform('max'); al=l.where(asia).groupby(dd).transform('min')
    rng=ah-al
    for win,tpR,slmode in [((10,13),1.0,'mid'),((10,13),1.5,'mid'),((10,13),2.0,'mid'),((10,12),1.5,'mid'),((10,13),1.5,'opp'),((10,13),2.0,'atr')]:
        inw=(hr>=win[0])&(hr<win[1])&(rng<4*atr*(3 if tfname=='M5' else 1.7))
        first_up=(c>ah)&(c.shift()<=ah); first_dn=(c<al)&(c.shift()>=al)
        sig=np.where(inw&first_up,1,np.where(inw&first_dn,-1,0))
        mid=(ah+al)/2
        if slmode=='mid': sl=mid
        elif slmode=='opp': sl=pd.Series(np.where(first_up,al,ah),index=d.index)
        else: sl=pd.Series(np.where(first_up,c-1.5*atr,c+1.5*atr),index=d.index)
        risk=(c-sl).abs(); tp=pd.Series(np.where(first_up,c+tpR*risk,c-tpR*risk),index=d.index)
        show(f'LonBO win{win} sl={slmode} tp{tpR}R',run(d,sig,sl,tp,exitHour=22,cooldown=0),days)
    print('=====',tfname,'NY opening-range breakout (16:30 server open)')
    for orEnd,tpR,trend in [(17,1.5,False),(17,2.0,False),(17,1.5,True),(17,2.0,True),(18,1.5,True)]:
        orm=(d.index.hour==16)&(d.index.minute>=30) | ((hr>16)&(hr<orEnd))
        oh=h.where(orm).groupby(dd).transform('max'); ol=l.where(orm).groupby(dd).transform('min')
        inw=(hr>=orEnd)&(hr<21)
        up=(c>oh)&(c.shift()<=oh); dn=(c<ol)&(c.shift()>=ol)
        if trend:
            e200=ema(c,200); up&=c>e200; dn&=c<e200
        sig=np.where(inw&up,1,np.where(inw&dn,-1,0))
        sl=(oh+ol)/2; risk=(c-sl).abs(); tp=pd.Series(np.where(up,c+tpR*risk,c-tpR*risk),index=d.index)
        show(f'NY-ORB end{orEnd} tp{tpR}R trendEMA200={trend}',run(d,sig,sl,tp,exitHour=23),days)
