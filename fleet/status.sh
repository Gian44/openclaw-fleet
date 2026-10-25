#!/bin/bash
# status.sh [--since <ISO or 'last'>] [--json]
# Prints a Discord-friendly markdown fleet report. '--since last' = only jobs finished
# since the previous report (used by the heartbeat cron).
set -u
source "$(dirname "$0")/common.sh"
SINCE=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in --since) SINCE="$2"; shift 2;; --json) JSON=1; shift;; *) shift;; esac
done
MARK="$FLEET_ROOT/.last_report"
if [ "$SINCE" = "last" ]; then SINCE="$(cat "$MARK" 2>/dev/null || echo 1970-01-01T00:00:00)"; fi
python3 - "$JOBS_DIR" "$SINCE" "$JSON" "${FLEET_STALE_MIN:-20}" <<'PY'
import json,os,sys,datetime
d,since,asjson=sys.argv[1],sys.argv[2],sys.argv[3]=="1"
STALE_MIN=float(sys.argv[4])
jobs=[]
def reconcile(p,st):
    """Job says running but result.json is complete -> finalize (wrapper was killed, claude.exe finished)."""
    try: r=json.load(open(f"{p}/result.json")); assert r.get("type")=="result"
    except Exception:
        age=(datetime.datetime.now()-datetime.datetime.strptime(st["started"],"%Y-%m-%dT%H:%M:%S")).total_seconds()/60
        if age>STALE_MIN:   # no result after a long time: the process was killed or crashed
            st["status"]="failed"; st["result"]=f"no result after {int(age)} min — process killed or crashed (see stderr.log)"
            st["finished"]=datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
            json.dump(st,open(f"{p}/status.json","w"),indent=2)
        return st
    st["result"]=(r.get("result") or "")[:1500]; st["cost_usd"]=r.get("total_cost_usd"); st["turns"]=r.get("num_turns")
    st["status"]="done" if (r.get("subtype")=="success" and not r.get("is_error")) else "failed"
    st["finished"]=datetime.datetime.fromtimestamp(os.path.getmtime(f"{p}/result.json")).strftime("%Y-%m-%dT%H:%M:%S")
    json.dump(st,open(f"{p}/status.json","w"),indent=2); return st
for j in sorted(os.listdir(d)):
    try:
        st=json.load(open(f"{d}/{j}/status.json"))
        if st["status"]=="running": st=reconcile(f"{d}/{j}",st)
        jobs.append(st)
    except Exception: pass
run=[x for x in jobs if x["status"]=="running"]
done=[x for x in jobs if x["status"]=="done"]
fail=[x for x in jobs if x["status"]=="failed"]
recent=[x for x in jobs if x["finished"] and x["finished"]>since]
cost=sum(x.get("cost_usd") or 0 for x in jobs)
if asjson:
    print(json.dumps({"running":len(run),"done":len(done),"failed":len(fail),"recent":recent,"cost_usd":round(cost,3)},indent=1)); sys.exit()
now=datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
print(f"**Fleet status** ({now}) — running: {len(run)} · done: {len(done)} · failed: {len(fail)} · spend: ${cost:.2f}")
for x in run: print(f"🟡 `{x['id']}` {x['name']} (since {x['started'][11:16]})")
if since:
    print(f"\n**Finished since last report** ({len(recent)}):")
    for x in recent:
        icon="✅" if x["status"]=="done" else "❌"
        summ=(x.get("result") or "").strip().splitlines()
        summ=" / ".join(s.strip() for s in summ[-3:]) if summ else "(no summary)"
        print(f"{icon} `{x['id']}` {x['name']} — {x.get('turns')} turns, ${(x.get('cost_usd') or 0):.2f}\n   {summ[:400]}")
PY
[ -n "$SINCE" ] && date +%Y-%m-%dT%H:%M:%S > "$MARK"
exit 0
