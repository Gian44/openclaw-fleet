#!/bin/bash
# dispatch.sh "<task text>" [--repo <path>] [--model sonnet|opus] [--name <label>] [--wait]
# Launches ONE headless Claude Code agent as a background job and returns its job id.
# Called by the OpenClaw "fleet" skill (from Discord) and by batch.sh.
set -u
source "$(dirname "$0")/common.sh"

TASK=""; REPO=""; MODEL="$FLEET_MODEL"; NAME=""; WAIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --name) NAME="$2"; shift 2;;
    --wait) WAIT=1; shift;;
    *) TASK="${TASK:+$TASK }$1"; shift;;
  esac
done
[ -z "$TASK" ] && { echo "usage: dispatch.sh \"task\" [--repo path] [--model m] [--name n] [--wait]"; exit 2; }
JOB_ID="$(date +%Y%m%d-%H%M%S)-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
JOB="$JOBS_DIR/$JOB_ID"; mkdir -p "$JOB"

# No --repo given: every agent gets its OWN copy of the sandbox, so N agents never
# fight over one working tree. (--repo <path> lets you point at a real project instead.)
if [ -z "$REPO" ]; then
  [ -d "$SANDBOX_DIR" ] || { echo "sandbox not found: $SANDBOX_DIR (run install.sh)"; exit 2; }
  cp -r "$SANDBOX_DIR" "$JOB/work"
  REPO="$JOB/work"
fi
# Pre-create the job branch so the agent only has to commit.
git -C "$REPO" checkout -q -b "fleet/$JOB_ID" 2>/dev/null || true
[ -d "$REPO" ] || { echo "repo not found: $REPO"; exit 2; }
[ -z "$NAME" ] && NAME="$(echo "$TASK" | cut -c1-60)"

printf '%s\n' "$TASK" > "$JOB/task.md"
python3 - "$JOB" "$NAME" "$REPO" "$MODEL" <<'PY'
import json,sys,time
job,name,repo,model=sys.argv[1:5]
json.dump({"id":job.split("/")[-1],"name":name,"repo":repo,"model":model,"status":"running",
           "started":time.strftime("%Y-%m-%dT%H:%M:%S"),"finished":None,"cost_usd":None,"turns":None,"result":None},
          open(f"{job}/status.json","w"),indent=2)
PY

PROMPT="You are one agent in an unattended overnight fleet. Work ONLY inside the current repository. Task:

$TASK

Rules: you are already on branch fleet/$JOB_ID. Make the change, run the tests/linters that exist, commit with a conventional-commit message, and finish with a 3-line summary: what changed, test result, anything blocked. Run shell commands ONE at a time (never chain with && or ;) because chained commands need approval you cannot get. Do not ask questions; if blocked, say so and stop."

run_job() {
  cd "$REPO" || exit 1
  "$CLAUDE_BIN" -p "$PROMPT" \
    --model "$MODEL" \
    --output-format json \
    --max-turns "$FLEET_MAX_TURNS" \
    --permission-mode acceptEdits \
    --allowedTools "$FLEET_ALLOWED_TOOLS" \
    < /dev/null > "$JOB/result.json" 2> "$JOB/stderr.log"
  echo $? > "$JOB/exit_code"
  python3 - "$JOB" <<'PY'
import json,sys,time
job=sys.argv[1]
st=json.load(open(f"{job}/status.json"))
try:
    r=json.load(open(f"{job}/result.json"))
    st["result"]=(r.get("result") or "")[:1500]
    st["cost_usd"]=r.get("total_cost_usd")
    st["turns"]=r.get("num_turns")
    st["status"]="done" if (r.get("subtype")=="success" and not r.get("is_error")) else "failed"
except Exception as e:
    st["status"]="failed"; st["result"]=f"no parsable result: {e}"
st["finished"]=time.strftime("%Y-%m-%dT%H:%M:%S")
json.dump(st,open(f"{job}/status.json","w"),indent=2)
PY
}

if [ "$WAIT" = 1 ]; then
  run_job; cat "$JOB/status.json"
else
  nohup bash -c "$(declare -f run_job); $(declare -p CLAUDE_BIN REPO PROMPT MODEL FLEET_MAX_TURNS FLEET_ALLOWED_TOOLS JOB); run_job" >/dev/null 2>&1 &
  echo "dispatched job $JOB_ID ($NAME) model=$MODEL repo=$REPO"
fi
