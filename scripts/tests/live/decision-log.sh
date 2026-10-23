#!/usr/bin/env bash
# Live check of decision-log's prompt-type Stop hook, which no fixture can test: a small model
# judges each turn. Runs three headless sessions in throwaway repos (about a minute; it uses
# your Claude account). Not run by validate.sh. Exit 0 = all pass, 1 = a check failed.
#   1. Stop hook alone, a turn that settles a decision: the hook must make Claude log it.
#   2. Stop hook alone, a turn that settles none: nothing is logged.
#   3. The whole plugin, a turn that settles a decision: it ends up in the branch log.
set -uo pipefail
command -v claude >/dev/null || { echo "live decision-log: claude not on PATH, skipped"; exit 0; }
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES CLAUDE_PROJECT_DIR
plugin="$(cd "$(dirname "$0")/../../.." && pwd)/plugins/decision-log"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/decision-log-live.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT; [ -n "${KEEP:-}" ] && echo "fixture: $tmp"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
fails=0

# A copy of the plugin with only the Stop hook, so the session context can't prompt the logging.
s="$tmp/stop-only"; mkdir -p "$s/.claude-plugin" "$s/hooks"
printf '{"name":"stop-only","version":"0.0.0","description":"decision-log Stop hook alone"}\n' > "$s/.claude-plugin/plugin.json"
jq '{hooks: {Stop: .hooks.Stop}}' "$plugin/hooks/hooks.json" > "$s/hooks/hooks.json" || exit 1

repo() {
  mkdir -p "$tmp/$1" && cd "$tmp/$1" && git init -q && git symbolic-ref HEAD refs/heads/main &&
    git config user.email t@example.com && git config user.name t &&
    printf 'export function greet(name) {\n  return "Hello " + name\n}\n' > greet.js &&
    git add -A && git commit -qm init && git checkout -q -b feat/greeting
}
session() { (cd "$tmp/$1" && claude -p --plugin-dir "$2" --permission-mode acceptEdits "$3" > reply.txt 2>&1); }
check() { eval "$2" || { echo "FAIL: $1 (reply: $(head -c 300 "$tmp/$3/reply.txt"))"; fails=$((fails + 1)); }; }

decide="greet.js has no handling for an empty name. Make greet('') return 'Hello there' rather than throwing an error or returning 'Hello ' - a friendly default is better for the UI. Edit the file, then reply in one sentence."
ask="What does greet('Ann') in greet.js return? Answer in one sentence and don't change any files."
repo a && repo b && repo c || exit 1
session a "$s" "$decide" & session b "$s" "$ask" & session c "$plugin" "$decide" & wait

log=.harness/decisions/feat__greeting.md
check "Stop hook alone: the decision was logged" '[ -f "$tmp/a/$log" ]' a
check "no decision: nothing logged" '[ ! -d "$tmp/b/.harness/decisions" ]' b
check "whole plugin: the decision was logged" 'grep -q "^## " "$tmp/c/$log" 2>/dev/null' c
if [ "$fails" -gt 0 ]; then echo "live decision-log: $fails of 3 checks failed"; exit 1; fi
echo "live decision-log: 3 checks passed"
