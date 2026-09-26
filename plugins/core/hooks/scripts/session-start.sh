#!/usr/bin/env bash
# SessionStart: stdout becomes context for the session. Orient Claude fast:
# mode, detected stacks, git state, current task, last handoff, recent learnings.
source "$(dirname "$0")/common.sh"

root="$(project_dir)"
mode="$(harness_mode)"
H="$root/.harness"

echo "## Harness context"
echo "- Mode: **${mode}** (change with HARNESS_MODE env var or .harness/mode). interactive = light checks; parallel/auto = strict stop checks, progress log."
echo "- Harness scripts dir: ${CLAUDE_PLUGIN_ROOT:-unknown}/scripts (worktree.sh lives here)"

# Stack detection (shallow, skips heavy dirs)
stacks=""
found() { find "$root" -maxdepth 3 \( -name node_modules -o -name target -o -name .git -o -name vendor -o -name dist -o -name build \) -prune -o -name "$1" -print -quit 2>/dev/null; }
pj="$(found package.json)"
if [ -n "$pj" ]; then
  s="ts"
  grep -q '"next"' "$pj" 2>/dev/null && s="$s/next"
  grep -q '"expo"' "$pj" 2>/dev/null && s="$s/expo"
  grep -q '"react"' "$pj" 2>/dev/null && s="$s/react"
  stacks="$stacks $s"
fi
[ -n "$(found go.mod)" ] && stacks="$stacks go"
[ -n "$(found Cargo.toml)" ] && stacks="$stacks rust"
[ -n "$(found pyproject.toml)" ] && stacks="$stacks python"
echo "- Detected stacks:${stacks:- none}"
if ls "$root"/architecture/*.c4 >/dev/null 2>&1; then
  echo "- Architecture model: \`architecture/\` (LikeC4). Read it before cross-service work; update it in the same change when services, stores, or dependencies change (architecture skill)."
fi

if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  br="$(git -C "$root" branch --show-current 2>/dev/null)"
  dirty="$(git -C "$root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  echo "- Git: branch \`${br:-detached}\`, ${dirty} uncommitted file(s)"
fi

if [ -f "$H/ports.env" ]; then
  echo "- Worktree ports (use these, not defaults): $(grep -v '^#' "$H/ports.env" | tr '\n' ' ')"
fi

if [ -f "$H/current-task" ]; then
  t="$(head -n1 "$H/current-task")"
  if [ -f "$root/$t" ]; then
    echo
    echo "## Current task: $t"
    head -n 50 "$root/$t"
  fi
fi

# Most recent handoff (manual beats auto if newer)
latest=""
for f in "$H/handoff.md" "$H/handoff-auto.md"; do
  [ -f "$f" ] || continue
  if [ -z "$latest" ] || [ "$f" -nt "$latest" ]; then latest="$f"; fi
done
if [ -n "$latest" ]; then
  echo
  echo "## Last handoff ($(basename "$latest"))"
  head -n 60 "$latest"
fi

if [ -f "$H/learnings.md" ]; then
  echo
  echo "## Project learnings (most recent)"
  tail -n 25 "$H/learnings.md"
fi
G="${HOME}/.claude/harness/learnings.md"
if [ -f "$G" ]; then
  echo
  echo "## Global learnings (most recent)"
  tail -n 15 "$G"
fi
exit 0
