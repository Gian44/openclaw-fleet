# openclaw-fleet

**Discord → OpenClaw → a fleet of headless Claude Code agents, running unattended, reporting back to Discord.**

Built by Gian Renomeron (Palo, Leyte, PH) as a working reference for "run AI agents like a fleet":
type a task in Discord, OpenClaw dispatches it to a Claude Code agent on my machine, N agents run in
parallel in isolated worktrees, a heartbeat cron posts what finished every 30 minutes, and a 7 AM
report lists what needs a human.

```
 Discord #general ──► OpenClaw gateway (WSL2, systemd) ──► fleet skill (exec)
                           │                                   │
                           │  cron: every 30m / 07:00          ▼
                           │                            fleet/dispatch.sh ── N× ──► claude.exe -p  (headless Claude Code)
                           │                                   │                      each in its own copy of the repo,
                           ▼                                   ▼                      own branch fleet/<job-id>
                 "✅ job … done, 12 turns, $0.41"      C:\Users\renom\fleet\jobs\<id>\{task.md,status.json,result.json,work\}
```

## What is in the box

| Path | What it does |
|---|---|
| `fleet/dispatch.sh` | Launch **one** headless Claude Code agent as a background job. Copies the sandbox, pre-creates branch `fleet/<id>`, runs `claude -p` with a locked-down tool allowlist, writes `status.json` (cost, turns, summary). |
| `fleet/batch.sh` | One task per line → up to `FLEET_MAX_PARALLEL` (default 8) agents at once, the rest queue. |
| `fleet/status.sh` | Discord-markdown fleet report. `--since last` = only what finished since the previous report (what the heartbeat uses). |
| `fleet/common.sh` | Knobs: model (default `sonnet`, cheap), max turns, parallelism, allowed tools. |
| `skills/fleet/SKILL.md` | The OpenClaw skill. Teaches the Discord agent when to call dispatch / batch / status and to never paraphrase tasks. |
| `tasks/overnight.txt` | The 8-task overnight batch used in the demo. |
| `sandbox/` | Tiny Python package with deliberate gaps (no zero-check in `divide`, `mean([])` crashes) so agents have real work. |
| `install.sh` | Copies sandbox + skill into place and registers the two OpenClaw cron jobs. |
| `windows/keepalive.ps1` | Scheduled Task that keeps WSL2 alive so the gateway survives the night (WSL otherwise shuts the distro down when idle). |

## Design decisions (the parts that matter when you run 10–20 agents)

- **Isolation per agent.** Every job gets its own copy of the repo and its own branch. No shared working tree, no merge races. Review = look at `fleet/*` branches in the morning.
- **Unattended means no prompts.** `--permission-mode acceptEdits` + an explicit `--allowedTools` list (read/write/edit, pytest, ruff, git add/commit/checkout). Anything outside the list is denied, not asked. The prompt also tells the agent to run commands one at a time; chained `&&` commands need approval the agent can't get.
- **Cheap by default.** Jobs run on Sonnet unless the dispatcher says `--model opus`. The first demo job: 12 turns, 54 s, $0.41.
- **OpenClaw is the operator, not the coder.** The Discord-facing agent (GPT via OpenAI key) only dispatches, polls and reports. The coding happens in Claude Code, which keeps my existing `/orch` setup, hooks and skills.
- **Loopback-only gateway, token auth, one allowlisted Discord user, one channel.** OpenClaw's track record (CVE-2026-25253, malicious ClawHub skills) is why there are zero third-party skills installed and the bot ignores everyone but me.
- **Heartbeat is cheap.** `status.sh --since last` is a file read; the 30-minute cron only spends tokens when something actually finished.

## Setup (WSL2 Ubuntu on Windows 11)

```bash
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
openclaw onboard --non-interactive --accept-risk --mode local --flow quickstart \
  --auth-choice openai-api-key --openai-api-key "$OPENAI_API_KEY" \
  --gateway-bind loopback --gateway-auth token --install-daemon --agent-name Fleet
openclaw plugins install @openclaw/discord
echo "DISCORD_BOT_TOKEN=..." > ~/.openclaw/.env && chmod 600 ~/.openclaw/.env
openclaw config patch --file openclaw/discord.patch.json5   # fill in your guild/channel/user ids
systemctl --user restart openclaw-gateway
bash install.sh
```
Windows side: `powershell -File windows/keepalive.ps1` once (registers the keep-alive task).
Claude Code must be installed and logged in on Windows (`claude auth status`); the bridge calls it through WSL interop.

## Using it from Discord

- `dispatch: <task>` → one agent, replies with the job id.
- paste a numbered list / `run these in parallel` → batch.
- `fleet status` → running / done / failed / spend.
- Every 30 min: "finished since last report" post. 07:00: overnight report + what needs a human.

## Demo run (2026-10-25)

See `docs/demo-run.md` for the screenshots and the status output of the 8-task overnight batch.
