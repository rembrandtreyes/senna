#!/usr/bin/env bash
# SubagentStop: when a critic or reviewer finishes, record its verdict with the hash of what it
# reviewed, in .harness/verdicts/. The Stop gates (core review-gate.sh, plan step-gate.sh) read
# these. Any subagent can take part by ending its output with these two lines:
#   REVIEWED: <repo-relative path>   (specs/<slug>/prd.md, specs/<slug>/spec.md, or a task file)
#   VERDICT: <PASS | FAIL | FIX FIRST>
# Never blocks.
source "$(dirname "$0")/common.sh"

msg="$(jget '.last_assistant_message')"
[ -n "$msg" ] || exit 0
verdict="$(printf '%s\n' "$msg" | sed -nE 's/^[[:space:]`*]*VERDICT:[[:space:]*]*([A-Za-z][A-Za-z ]*[A-Za-z]).*/\1/p' | head -n1)"
subject="$(printf '%s\n' "$msg" | sed -nE 's/^[[:space:]`*]*REVIEWED:[[:space:]*`]*([^[:space:]`*]+).*/\1/p' | head -n1)"
[ -n "$verdict" ] && [ -n "$subject" ] || exit 0

root="$(project_dir)"
top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$root")"
subject="${subject#"$top"/}"; subject="${subject#"$root"/}"; subject="${subject#./}"
case "$verdict" in
  PASS*) verdict=PASS ;;
  FIX*) verdict=FIX_FIRST ;;
  *) verdict=FAIL ;;
esac

f="$(verdict_file "$subject")"
mkdir -p "$(dirname "$f")" 2>/dev/null || exit 0
printf '%s %s %s %s\n' "$verdict" "$(subject_hash "$subject")" "$(jget '.agent_type')" \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$f" 2>/dev/null
exit 0
