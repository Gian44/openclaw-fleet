#!/bin/bash
# install.sh — run inside WSL2 Ubuntu after OpenClaw is onboarded.
# Wires this repo into OpenClaw: skill, sandbox, job dirs, heartbeat crons.
set -e
export PATH=$HOME/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/fleet/common.sh"

DISCORD_CHANNEL="${DISCORD_CHANNEL:-1563771258359906407}"   # #general in the Fleet Ops server

echo "[1/4] sandbox -> $SANDBOX_DIR"
mkdir -p "$FLEET_ROOT" "$JOBS_DIR"
rm -rf "$SANDBOX_DIR"; cp -r "$HERE/sandbox" "$SANDBOX_DIR"
( cd "$SANDBOX_DIR" && git init -q && git add -A && git -c user.name=fleet -c user.email=fleet@local commit -qm "chore: sandbox baseline" )

echo "[2/4] skill -> ~/.openclaw/workspace/skills/fleet"
SK=~/.openclaw/workspace/skills/fleet
mkdir -p "$SK/bin"
cp "$HERE/skills/fleet/SKILL.md" "$SK/SKILL.md"
cp "$HERE/fleet/"*.sh "$SK/bin/"
chmod +x "$SK/bin/"*.sh

echo "[3/4] heartbeat + morning report crons"
openclaw cron list --json 2>/dev/null | grep -q '"fleet-heartbeat"' || \
openclaw cron add "every 30m" "Run the fleet skill: bash ~/.openclaw/workspace/skills/fleet/bin/status.sh --since last . If it shows 0 running and 0 finished, reply with exactly: fleet idle. Otherwise post the output as-is." \
  --name fleet-heartbeat --session isolated --announce --channel discord --to "channel:$DISCORD_CHANNEL"
openclaw cron list --json 2>/dev/null | grep -q '"fleet-morning-report"' || \
openclaw cron add "0 7 * * *" "Run: bash ~/.openclaw/workspace/skills/fleet/bin/status.sh . Post it under the heading **Overnight fleet report**, then add one line: which jobs need a human look (failed or blocked)." \
  --name fleet-morning-report --tz Asia/Singapore --session isolated --announce --channel discord --to "channel:$DISCORD_CHANNEL"

echo "[4/4] done. Test: bash $SK/bin/dispatch.sh \"Add a test for subtract with negatives\" --wait"
openclaw cron list 2>/dev/null | tail -5
