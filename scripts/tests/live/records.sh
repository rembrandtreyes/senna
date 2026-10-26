#!/usr/bin/env bash
# Live check of /records against a real source, which no fixture can test: it runs the
# records-sync agent through a connector. Skipped unless RECORDS_SOURCE is set to a decision
# records URL you can read (a Notion database, say); a team's URL never goes in this repo.
# RECORDS_TOOLS names the connector's tools to allow (default: the claude.ai Notion connector).
# One headless session in a throwaway repo; uses your Claude account. Not run by validate.sh.
# Exit 0 = all pass, 1 = a check failed.
set -uo pipefail
[ -n "${RECORDS_SOURCE:-}" ] || { echo "live records: RECORDS_SOURCE not set, skipped"; exit 0; }
command -v claude >/dev/null || { echo "live records: claude not on PATH, skipped"; exit 0; }
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES CLAUDE_PROJECT_DIR
plugin="$(cd "$(dirname "$0")/../../.." && pwd)/plugins/core"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/records-live.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT; [ -n "${KEEP:-}" ] && echo "fixture: $tmp"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
fails=0

r="$tmp/repo"; mkdir -p "$r/.harness" && cd "$r" || exit 1
git init -q && git symbolic-ref HEAD refs/heads/main
git config user.email t@example.com && git config user.name t && git config commit.gpgsign false
printf '%s\n' "$RECORDS_SOURCE" > .harness/records-source
git add -A && git commit -qm init

(cd "$r" && echo "/records" | claude -p --plugin-dir "$plugin" --permission-mode acceptEdits \
  --allowedTools "Read,Write,Glob,Grep,Bash(mkdir:*),Bash(rm:*),Agent,Task,${RECORDS_TOOLS:-mcp__claude_ai_Notion}" \
  > "$tmp/reply.txt" 2>&1)

check() { eval "$2" || { echo "FAIL: $1"; fails=$((fails + 1)); }; }
R="$r/.harness/records"
check "an index with the source and sync time" 'grep -q "^Source: " "$R/index.md" && grep -q "^Synced: " "$R/index.md"'
check "record files, each with a status and a source link" 'n=0; for f in "$R"/*.md; do [ "$(basename "$f")" = index.md ] && continue; grep -qE "^Status: (accepted|proposed|declined|superseded)" "$f" && grep -q "^Source: " "$f" || { n=-1; break; }; n=$((n + 1)); done; [ "$n" -gt 0 ]'
log="$HOME/.claude/projects/$(cd "$r" && pwd -P | sed 's|[^A-Za-z0-9]|-|g')"
check "the session log was found" '[ -n "$(find "$log" -name "*.jsonl" 2>/dev/null | head -n 1)" ]'
check "nothing was written to the source" '! find "$log" -name "*.jsonl" -exec grep -hoE "\"name\":\"mcp__[^\"]*(create|update|delete|move|comment|duplicate)[^\"]*\"" {} + 2>/dev/null | grep -q .'
out="$(printf '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$r" bash "$plugin/hooks/scripts/session-start.sh" 2>&1)"
check "session start lists the copy" 'printf "%s\n" "$out" | grep -q "^## Decision records (.harness/records/: [1-9]"'
if [ "$fails" -gt 0 ]; then echo "live records: $fails of 5 checks failed (reply: $tmp/reply.txt; rerun with KEEP=1)"; exit 1; fi
echo "live records: 5 checks passed"
