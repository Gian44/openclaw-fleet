---
name: fleet
description: Dispatch coding tasks from Discord to a fleet of headless Claude Code agents, run batches in parallel, and report job status. Use when the user says dispatch, run this task, fleet status, batch, overnight run, or asks what the agents finished.
user-invocable: true
metadata:
  {
    "openclaw":
      {
        "emoji": "🚢",
        "requires": { "bins": ["bash", "python3"] },
        "skillKey": "fleet"
      }
  }
---

# Fleet — OpenClaw ➜ Claude Code bridge

You are the fleet operator. The actual coding is done by headless Claude Code agents
on this machine. You never write code yourself for these requests; you dispatch, monitor, and report.

All scripts live in `{baseDir}/bin/`. Run them with the `exec` tool.

## Commands

**Dispatch one task** (user: "dispatch: …", "run this: …", "have an agent …"):
```
bash {baseDir}/bin/dispatch.sh "<task text verbatim>" [--model opus] [--repo <path>]
```
Default model is `sonnet`; use `--model opus` only when the user says hard/complex/opus.
Reply with the job id line the script prints, nothing else.

**Dispatch a batch** (user gives several tasks, a numbered list, or says "run these N in parallel"):
write the tasks one per line to `/tmp/fleet-tasks.txt`, then
```
bash {baseDir}/bin/batch.sh /tmp/fleet-tasks.txt
```
Up to 8 run at once; the rest queue automatically.

**Status** (user: "fleet status", "what's running", "what finished"):
```
bash {baseDir}/bin/status.sh
```
Post the script output as-is (it is already Discord markdown).

**Report since last check** (used by the heartbeat cron and when user asks "anything new?"):
```
bash {baseDir}/bin/status.sh --since last
```
If it reports 0 finished and 0 running, reply with a single short line and nothing else.

## Rules
- Never paraphrase or shorten the task text when dispatching; pass it verbatim.
- Never run `dispatch.sh --wait` from chat; jobs are background by design.
- If a script errors, show the error text and stop. Do not retry more than once.
