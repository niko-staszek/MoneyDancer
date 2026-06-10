import csv
from datetime import date, timedelta
# daily high/low from ticks
daily={}  # 'YYYY-MM-DD' -> [hi,lo]
for f in ["data/duka/XAUUSD_2025_robo.csv","data/duka/XAUUSD_2026_jan-may_robo.csv"]:
    with open(f,newline='') as fh:
        r=csv.reader(fh); next(r)
        for row in r:
            if not row: continue
            d=row[0][:10]
            try: bid=float(row[1])
            except: continue
            x=daily.get(d)
            if x is None: daily[d]=[bid,bid]
            else:
                if bid>x[0]:x[0]=bid
                if bid<x[1]:x[1]=bid
months=["2025-01","2025-03","2025-04","2025-08","2025-09","2025-10","2025-11","2026-01","2026-02","2026-03"]
def days_in(ym):
    y,m=map(int,ym.split('-'))
    nm=date(y+(m//12),(m%12)+1,1); return [date(y,m,1)+timedelta(i) for i in range((nm-date(y,m,1)).days)]
print(f"{'month':8} {'worst 14d window':25} {'range%':>7}")
out=[]
for ym in months:
    dd=days_in(ym); best=None
    for i in range(len(dd)):
        win=[d for d in dd[i:i+14]]
        ks=[d.isoformat() for d in win if d.isoformat() in daily]
        if not ks: continue
        hi=max(daily[k][0] for k in ks); lo=min(daily[k][1] for k in ks)
        op=daily[ks[0]][0]
        rng=(hi-lo)/op*100
        if best is None or rng>best[0]: best=(rng,win[0],win[-1])
    rng,a,b=best
    # extend end by 1 day for inclusive tester to-date
    frm=a.strftime("%Y.%m.%d"); to=(b+timedelta(1)).strftime("%Y.%m.%d")
    sym="XAUUSD.duk_robo" if ym.startswith("2026") else "XAUUSD.duk_robo_2025"
    out.append((ym,frm,to,sym,rng))
    print(f"{ym:8} {frm}..{to:12} {rng:7.2f}")
import json
json.dump(out,open("/tmp/worstwin.json","w"))
