#!/usr/bin/env bash
# Live check of the verdict recorder, which no fixture can test: whether Claude Code runs the
# SubagentStop hook with the reviewer's report in last_assistant_message, so the verdict lands
# where the review gate looks. Two headless sessions in throwaway repos (a few minutes; it uses
# your Claude account): one runs the reviewer in the foreground, one in the background. An
# installed core is turned off for them, so only this copy's hooks run. Not run by validate.sh.
# Exit 0 = all pass, 1 = a check failed. KEEP=1 keeps the repos and prints the hook's records.
set -uo pipefail
command -v claude >/dev/null || { echo "live review-gate: claude not on PATH, skipped"; exit 0; }
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES CLAUDE_PROJECT_DIR HARNESS_MODE
plugin="$(cd "$(dirname "$0")/../../.." && pwd)/plugins/core"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/review-gate-live.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT; [ -n "${KEEP:-}" ] && echo "fixture: $tmp"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 HARNESS_REVIEW_GATE=off
fails=0

# A task marked review, and its change left uncommitted.
repo() {
  mkdir -p "$tmp/$1/tasks" && cd "$tmp/$1" && git init -q && git symbolic-ref HEAD refs/heads/main &&
    git config user.email t@example.com && git config user.name t && git config commit.gpgsign false &&
    printf 'export function greet(name) {\n  return "Hello " + name\n}\n' > greet.js &&
    printf '# T-1: a friendly default greeting\nStatus: review\n\n## Acceptance criteria\n- greet("") returns "Hello there".\n' \
      > tasks/T-1-greet.md &&
    git add -A && git commit -qm init &&
    printf 'export function greet(name) {\n  return "Hello " + (name || "there")\n}\n' > greet.js &&
    mkdir -p .harness && echo tasks/T-1-greet.md > .harness/current-task
}
session() {
  (cd "$tmp/$1" && printf '%s' "$2" | claude -p --plugin-dir "$plugin" \
    --settings '{"enabledPlugins":{"core@senna":false}}' \
    --allowedTools "Read,Grep,Glob,Agent,Task,Bash(git:*),Bash(ls:*),Bash(cat:*)" > reply.txt 2>&1)
}
check() { eval "$2" || { echo "FAIL: $1 (reply: $(head -c 300 "$tmp/$3/reply.txt"))"; fails=$((fails + 1)); }; }
records() {
  local f; for f in "$tmp/$1/.harness/.record-verdict.prev.log" "$tmp/$1/.harness/.record-verdict.log"; do
    [ -f "$f" ] && cat "$f"; done; return 0
}

ask="Run the core:reviewer subagent on the task in .harness/current-task"
end="Don't edit any files. When it's done, reply with its VERDICT line only."
repo fg && repo bg || exit 1
session fg "$ask, in the foreground. $end" & session bg "$ask with run_in_background set to true, and wait for its report. $end" & wait

for s in fg bg; do
  check "$s: the hook ran for the reviewer" 'records "$s" | grep -q "^agent_type=core:reviewer$"' "$s"
  check "$s: the report reached the hook" 'records "$s" | grep -qE "^message_chars=[1-9]"' "$s"
  check "$s: the verdict was written where the gate looks" 'records "$s" | grep -qE "^outcome=wrote: (PASS|FIX_FIRST) " &&
    grep -qE "^(PASS|FIX_FIRST) " "$tmp/$s/.harness/verdicts/tasks__T-1-greet.md"' "$s"
  [ -n "${KEEP:-}" ] && { echo "--- $s records"; records "$s"; }
done

if [ "$fails" -gt 0 ]; then echo "live review-gate: $fails checks failed"; exit 1; fi
echo "live review-gate: all checks passed"
