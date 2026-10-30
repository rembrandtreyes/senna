#!/usr/bin/env bash
# Fixture test for core's verdict recorder (SubagentStop) and review gate (Stop): what the
# recorder writes, the record it leaves in .harness/.record-verdict.log on each path, and that the
# gate finds what it wrote. Pipes hook JSON into the hooks with CLAUDE_PROJECT_DIR set to a
# throwaway repo.
# Run by scripts/validate.sh. Exit 0 = all pass, 1 = a check failed.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES HARNESS_MODE HARNESS_REVIEW_GATE \
  CLAUDE_PROJECT_DIR
scripts="$(cd "$(dirname "$0")/../.." && pwd)/plugins/core/hooks/scripts"
sh_bin=bash; [ -x /bin/bash ] && sh_bin=/bin/bash
tmp="$(mktemp -d "${TMPDIR:-/tmp}/record-verdict-test.XXXXXX")" || exit 1
trap 'chmod -R u+w "$tmp" 2>/dev/null; [ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT
[ -n "${KEEP:-}" ] && echo "fixture: $tmp"
fails=0; checks=0

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 HOME="$tmp/home"
r="$tmp/repo"; mkdir -p "$r" "$HOME" && cd "$r" || exit 1
git init -q && git symbolic-ref HEAD refs/heads/main
git config user.email t@example.com; git config user.name t; git config commit.gpgsign false
mkdir tasks && printf 'Status: review\n\n# T-1\n' > tasks/T-1-x.md && echo x > a.txt
git add -A && git commit -qm init
mkdir -p .harness && echo tasks/T-1-x.md > .harness/current-task

ok() { checks=$((checks + 1)); eval "$2" || { echo "FAIL: $1"; fails=$((fails + 1)); }; }
# stop <agent_type> <message> [cwd] : the recorder as SubagentStop; sets code and err (stderr)
stop() {
  local in; in="$(jq -cn --arg t "$1" --arg m "$2" --arg c "${3:-$r}" '{hook_event_name:"SubagentStop",
    agent_type:$t, agent_id:"a1", agent_transcript_path:"/x/a1.jsonl", cwd:$c, last_assistant_message:$m}')"
  err="$(printf '%s' "$in" | CLAUDE_PROJECT_DIR="$r" "$sh_bin" "$scripts/record-verdict.sh" 2>&1 >/dev/null)"
  code=$?
}
# gate : the review gate's lookup alone (its ask-once memory cleared); sets gcode
gate() {
  rm -f .harness/.gate-*
  printf '{"stop_hook_active":false}' | CLAUDE_PROJECT_DIR="$r" "$sh_bin" "$scripts/review-gate.sh" >/dev/null 2>&1
  gcode=$?
}
L=.harness/.record-verdict.log; P=.harness/.record-verdict.prev.log; V=.harness/verdicts/tasks__T-1-x.md
field() { sed -n "s/^$1=//p" "${2:-$L}"; }
pass="REVIEWED: tasks/T-1-x.md
VERDICT: PASS"

# Subagents that aren't reviewing leave nothing.
stop Explore "Found 3 files."
ok "other subagent: exit 0, nothing written" '[ "$code" -eq 0 ] && [ ! -e "$L" ] && [ ! -e .harness/verdicts ]'
stop plan:architecture-reviewer "Findings: none"
ok "lens reviewer without verdict lines: no record" '[ ! -e "$L" ]'
gate; ok "no verdict: the gate blocks" '[ "$gcode" -eq 2 ]'

# A reviewer whose report never reached the hook.
stop core:reviewer ""
ok "empty message: exit 0, quiet" '[ "$code" -eq 0 ] && [ -z "$err" ]'
ok "empty message: says so" 'field outcome | grep -q "last_assistant_message is empty"'
ok "empty message: names the reviewer and run" '[ "$(field agent_type)" = core:reviewer ] && [ "$(field agent_id)" = a1 ] && [ "$(field event)" = SubagentStop ]'
ok "empty message: no verdict" '[ ! -e "$V" ]'

# Missing lines.
stop core:reviewer "VERDICT: PASS"
ok "no REVIEWED line: says so" 'field outcome | grep -q "no line starting REVIEWED"'
ok "no REVIEWED line: the run before is kept" 'field outcome "$P" | grep -q "last_assistant_message is empty"'
stop core:reviewer "## VERDICT: PASS
REVIEWED: tasks/T-1-x.md"
ok "unparsed VERDICT line: says so, and shows the line" 'field outcome | grep -q "no line starting VERDICT" && [ "$(field verdict_line)" = "## VERDICT: PASS" ]'

# A ticket where the task path belongs: written under the ticket, and the record shows the miss.
stop core:reviewer "REVIEWED: ABC-123, commits abc
VERDICT: PASS"
ok "ticket subject: keyed by the ticket" '[ -f ".harness/verdicts/ABC-123," ] && [ ! -e "$V" ]'
ok "ticket subject: mismatch shown" '[ "$(field subject)" = "ABC-123," ] && [ "$(field subject_is_file)" = no ] && [ "$(field current_task)" = tasks/T-1-x.md ] && [ "$(field matches_current_task)" = no ]'
gate; ok "ticket subject: the gate still blocks" '[ "$gcode" -eq 2 ]'

# The task path, formatted the way reviewers print it: recorded, and the gate passes.
stop core:reviewer "**REVIEWED:** \`tasks/T-1-x.md\` (re-review of abc)
**VERDICT:** PASS
BODY-LINE-NOT-FOR-THE-LOG"
ok "pass: exit 0" '[ "$code" -eq 0 ] && [ -z "$err" ]'
ok "pass: verdict written" '[ "$(cut -d" " -f1 "$V")" = PASS ] && [ "$(cut -d" " -f3 "$V")" = core:reviewer ]'
ok "pass: outcome is the written line" '[ "$(field outcome)" = "wrote: $(cat "$V")" ]'
ok "pass: root, destination, and match recorded" '[ "$(field root)" = "$r" ] && [ "$(field dest)" = "$r/$V" ] && [ "$(field matches_current_task)" = yes ]'
ok "pass: the report itself isn't stored" '! grep -q BODY-LINE "$L" "$P"'
gate; ok "pass: the gate passes" '[ "$gcode" -eq 0 ]'
stop general-purpose "$pass"
ok "any subagent with the lines is recorded" '[ "$(cut -d" " -f3 "$V")" = general-purpose ] && [ "$(field agent_type)" = general-purpose ]'

# FIX FIRST stays FIX FIRST, and the gate keeps its behavior: quiet until the code changes.
stop core:reviewer "REVIEWED: tasks/T-1-x.md
VERDICT: FIX FIRST"
ok "fix first: recorded" '[ "$(cut -d" " -f1 "$V")" = FIX_FIRST ]'
gate; ok "fix first, nothing changed since: the gate passes" '[ "$gcode" -eq 0 ]'
echo y >> a.txt
gate; ok "fix first, code changed since: the gate blocks" '[ "$gcode" -eq 2 ]'
git checkout -q a.txt

# A destination that can't be written: the record keeps the error, and the hook still exits 0.
rm -rf .harness/verdicts && echo x > .harness/verdicts
stop core:reviewer "$pass"
ok "mkdir fails: exit 0" '[ "$code" -eq 0 ]'
ok "mkdir fails: error recorded" 'field outcome | grep -q "^failed: mkdir: .*File exists"'
rm -f .harness/verdicts
if [ "$(id -u)" -ne 0 ]; then
  mkdir -p .harness/verdicts && chmod a-w .harness/verdicts
  stop core:reviewer "$pass"
  ok "write fails: exit 0" '[ "$code" -eq 0 ]'
  ok "write fails: error recorded" 'field outcome | grep -qi "^failed: write: .*permission denied"'
  chmod u+w .harness/verdicts
  chmod a-w .harness
  stop core:reviewer "$pass"
  ok "record can't be saved: exit 0" '[ "$code" -eq 0 ]'
  ok "record can't be saved: one line on stderr" 'printf "%s\n" "$err" | grep -q "could not save its diagnostic" && [ "$(printf "%s\n" "$err" | wc -l)" -eq 1 ]'
  ok "record can't be saved: verdict still written" '[ "$(cut -d" " -f1 "$V")" = PASS ]'
  chmod u+w .harness
fi

# Long lines are cut; the record stays under 4 KiB with its outcome.
long="$(printf '%5000s' '' | tr ' ' x)"
stop core:reviewer "REVIEWED: tasks/$long
VERDICT: PASS $long" "$r/$long"
ok "long input: exit 0" '[ "$code" -eq 0 ]'
ok "long input: under 4 KiB, outcome kept" '[ "$(wc -c < "$L")" -le 4096 ] && [ -n "$(field outcome)" ]'

# Concurrent runs: each record whole, no temp files left.
for i in 1 2 3 4 5 6; do stop core:reviewer "$pass" & done; wait
whole() { [ "$(grep -c "^time=" "$1")" -eq 1 ] && [ "$(grep -c "^outcome=" "$1")" -eq 1 ] && [ "$(tail -n 1 "$1" | cut -d= -f1)" = outcome ]; }
ok "concurrent: current record whole" 'whole "$L"'
ok "concurrent: previous record whole" 'whole "$P"'
ok "concurrent: no temp files left" '[ -z "$(find .harness -maxdepth 1 -name ".record-verdict.*.tmp")" ]'

# Without CLAUDE_PROJECT_DIR the hook falls back to the input cwd; the record says so.
mkdir -p sub
jq -cn --arg c "$r/sub" --arg m "$pass" '{agent_type:"core:reviewer", cwd:$c, last_assistant_message:$m}' \
  | "$sh_bin" "$scripts/record-verdict.sh" >/dev/null 2>&1
ok "no project dir: record shows the fallback root" '[ "$(field env_project_dir sub/$L)" = "(unset)" ] && [ "$(field root sub/$L)" = "$r/sub" ]'

if [ "$fails" -gt 0 ]; then echo "record-verdict: $fails of $checks checks failed"; exit 1; fi
echo "record-verdict: $checks checks passed"
