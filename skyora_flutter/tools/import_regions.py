#!/usr/bin/env python3
"""Import official nationwide administrative CSV + trusted coordinates CSV.

Usage:
 python tools/import_regions.py --codes official.csv --coords coordinates.csv

codes CSV columns: code,province,district,town
coords CSV columns: code,lat,lon (WGS84 latitude/longitude)

The script rejects missing/invalid coordinates instead of fabricating grid values.
Use a consistent code system (legal-dong OR administrative-dong) for both inputs.
"""
import argparse,csv,json,pathlib,sys
p=argparse.ArgumentParser();p.add_argument('--codes',required=True);p.add_argument('--coords',required=True);p.add_argument('--out',default='assets/data/regions.json');args=p.parse_args()
def load(path):
 with open(path,encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
coords={r['code'].strip():r for r in load(args.coords)}
result=[];missing=[];seen=set()
for r in load(args.codes):
 code=r['code'].strip()
 if code in seen:continue
 seen.add(code)
 if code not in coords:missing.append(code);continue
 try:lat=float(coords[code]['lat']);lon=float(coords[code]['lon'])
 except (ValueError,KeyError):missing.append(code);continue
 if not (32<=lat<=39.5 and 124<=lon<=132):missing.append(code);continue
 if not all(r.get(k,'').strip() for k in ('province','district','town')):continue
 result.append({'code':code,'province':r['province'].strip(),'district':r['district'].strip(),'town':r['town'].strip(),'lat':lat,'lon':lon})
result.sort(key=lambda x:(x['province'],x['district'],x['town']))
out=pathlib.Path(args.out);out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Wrote {len(result)} regions; missing coordinates: {len(missing)}; output: {out}')
if missing:print('Missing codes (first 30):',','.join(missing[:30]),file=sys.stderr)
if not result:sys.exit('ERROR: no valid regions')
