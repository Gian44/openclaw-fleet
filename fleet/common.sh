#!/bin/bash
# Shared settings for the OpenClaw -> Claude Code fleet bridge (runs inside WSL2 Ubuntu).
export PATH=$HOME/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Windows-side Claude Code binary, called through WSL interop so it reuses the
# logged-in Windows ~/.claude (skills, hooks, /orch, subscription auth).
CLAUDE_BIN="${CLAUDE_BIN:-/mnt/c/Users/renom/.local/bin/claude.exe}"

# Where jobs run and log. Windows-side so both claude.exe and WSL can see it.
FLEET_ROOT="${FLEET_ROOT:-/mnt/c/Users/renom/fleet}"
JOBS_DIR="$FLEET_ROOT/jobs"
SANDBOX_DIR="${SANDBOX_DIR:-$FLEET_ROOT/sandbox}"

# Defaults for unattended runs.
FLEET_MODEL="${FLEET_MODEL:-sonnet}"      # cheap by default; "opus" for hard tasks
FLEET_MAX_TURNS="${FLEET_MAX_TURNS:-25}"
FLEET_MAX_PARALLEL="${FLEET_MAX_PARALLEL:-8}"
# Tools the headless agent may use without prompting. Everything else is denied.
FLEET_ALLOWED_TOOLS="${FLEET_ALLOWED_TOOLS:-Read,Write,Edit,MultiEdit,Glob,Grep,LS,Bash(python*),Bash(pytest*),Bash(pip *),Bash(uv *),Bash(npm *),Bash(npx *),Bash(node *),Bash(git status*),Bash(git diff*),Bash(git log*),Bash(git add*),Bash(git commit*),Bash(git checkout*),Bash(git switch*),Bash(git branch*),Bash(ls*),Bash(cat*),Bash(mkdir*),Bash(ruff*)}"

mkdir -p "$JOBS_DIR"

to_win_path() { # /mnt/c/x -> C:\x
  echo "$1" | sed -E 's#^/mnt/([a-z])/#\U\1:\\#; s#/#\\#g'
}
