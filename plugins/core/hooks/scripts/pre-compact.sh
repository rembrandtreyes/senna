#!/usr/bin/env bash
# PreCompact: snapshot mechanical state so compaction can't lose the thread.
# (/handoff writes the richer, human-readable version.)
source "$(dirname "$0")/common.sh"

root="$(project_dir)"
H="$root/.harness"; mkdir -p "$H"
out="$H/handoff-auto.md"
{
  echo "# Auto handoff ($(date -u +%Y-%m-%dT%H:%M:%SZ), trigger: $(jget '.trigger'))"
  echo
  [ -f "$H/current-task" ] && echo "Current task: $(head -n1 "$H/current-task")"
  if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Branch: $(git -C "$root" branch --show-current 2>/dev/null)"
    echo
    echo "## Uncommitted changes"
    git -C "$root" status --short 2>/dev/null | head -n 40
    echo
    echo "## Diff stat"
    git -C "$root" diff --stat HEAD 2>/dev/null | tail -n 25
    echo
    echo "## Recent commits"
    git -C "$root" log --oneline -n 8 2>/dev/null
  fi
  if [ -f "$H/progress.log" ]; then
    echo
    echo "## Last actions"
    tail -n 15 "$H/progress.log"
  fi
} > "$out"
exit 0
