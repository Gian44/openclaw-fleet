#!/bin/bash
# batch.sh <tasks-file> [--repo <path>] [--model m]
# One task per line. Launches up to FLEET_MAX_PARALLEL agents at once, queues the rest.
set -u
source "$(dirname "$0")/common.sh"
FILE="$1"; shift
EXTRA=("$@")
[ -f "$FILE" ] || { echo "tasks file not found: $FILE"; exit 2; }

running() { # count jobs still running
  python3 - "$JOBS_DIR" <<'PY'
import json,os,sys
d=sys.argv[1]; n=0
for j in os.listdir(d):
    try:
        if json.load(open(f"{d}/{j}/status.json"))["status"]=="running": n+=1
    except Exception: pass
print(n)
PY
}

N=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue;; esac
  while [ "$(running)" -ge "$FLEET_MAX_PARALLEL" ]; do sleep 15; done
  bash "$(dirname "$0")/dispatch.sh" "$line" "${EXTRA[@]}"
  N=$((N+1))
  sleep 2
done < "$FILE"
echo "batch: launched $N jobs (max parallel $FLEET_MAX_PARALLEL)"
