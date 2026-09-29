#!/usr/bin/env bash
# Stop: once the current task is marked review or done, require a reviewer verdict on it.
#   no verdict yet         -> ask Claude to run the reviewer
#   FIX FIRST, code since  -> ask for a re-review of the fixes
#   PASS                   -> done (later small edits don't re-trigger it)
# Asks once per state of the work, so if the user chose to skip the review it isn't re-asked.
# HARNESS_REVIEW_GATE=off disables it.
source "$(dirname "$0")/common.sh"

[ "${HARNESS_REVIEW_GATE:-on}" = off ] && exit 0
root="$(project_dir)"
[ -f "$root/.harness/current-task" ] || exit 0
task="$(tr -d '\n' < "$root/.harness/current-task")"
task="${task#"$root"/}"
[ -f "$root/$task" ] || exit 0
status="$(grep -m1 -E '^Status:' "$root/$task" | sed -E 's/^Status:[[:space:]]*//; s/[[:space:]#].*//')"
case "$status" in review|done) ;; *) exit 0 ;; esac

v="$(verdict_file "$task")"
now="$(work_hash)"
if [ -f "$v" ]; then
  read -r verdict hash _ < "$v"
  [ "$verdict" = PASS ] && exit 0
  [ "$hash" = "$now" ] && exit 0   # FIX FIRST and nothing changed since: the user has the report
  why="the reviewer's last verdict was FIX FIRST and the code has changed since"
else
  why="no reviewer verdict is on record for it"
fi
gate_once "review-$(printf '%s' "$task" | sed 's|/|__|g')" "$now" || exit 0

cat >&2 <<EOF
Harness review gate: $task is marked "$status" but $why.
Run the reviewer subagent on it now (give it the harness scripts dir for rid-check.sh), fix any
blockers, then finish. If the user has chosen to skip the review, say so and finish; this is
asked once per state of the code.
EOF
exit 2
