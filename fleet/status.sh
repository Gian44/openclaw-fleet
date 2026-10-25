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
python3 - "$JOBS_DIR" "$SINCE" "$JSON" <<'PY'
import json,os,sys,datetime
d,since,asjson=sys.argv[1],sys.argv[2],sys.argv[3]=="1"
jobs=[]
for j in sorted(os.listdir(d)):
    try: jobs.append(json.load(open(f"{d}/{j}/status.json")))
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
