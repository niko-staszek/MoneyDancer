import csv
files = ["data/duka/XAUUSD_2025_robo.csv", "data/duka/XAUUSD_2026_jan-may_robo.csv"]
m = {}  # 'YYYY-MM' -> dict(open,close,hi,lo,n)
for f in files:
    with open(f, newline='') as fh:
        r = csv.reader(fh); next(r)  # header
        for row in r:
            if not row: continue
            dt = row[0]; ym = dt[:7]
            try: bid = float(row[1])
            except: continue
            d = m.get(ym)
            if d is None:
                m[ym] = {'open':bid,'close':bid,'hi':bid,'lo':bid,'n':1}
            else:
                d['close']=bid; d['n']+=1
                if bid>d['hi']: d['hi']=bid
                if bid<d['lo']: d['lo']=bid
rows=[]
for ym in sorted(m):
    d=m[ym]; o,c,hi,lo=d['open'],d['close'],d['hi'],d['lo']
    net=(c-o)/o*100; rng=(hi-lo)/o*100
    rows.append((ym,o,c,hi,lo,net,rng,d['n']))
print(f"{'month':8} {'open':>8} {'close':>8} {'net%':>7} {'range%':>7} {'ticks':>10}")
for ym,o,c,hi,lo,net,rng,n in rows:
    print(f"{ym:8} {o:8.1f} {c:8.1f} {net:+7.2f} {rng:7.2f} {n:10d}")
print("\n=== ranked by |net%| (trend magnitude = worst for counter-trend grid) ===")
for ym,o,c,hi,lo,net,rng,n in sorted(rows,key=lambda x:-abs(x[5]))[:12]:
    print(f"{ym}  net {net:+6.2f}%  range {rng:5.2f}%")
