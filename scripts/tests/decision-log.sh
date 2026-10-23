#!/usr/bin/env bash
# Fixture test for the decision-log plugin: pipes SessionStart JSON into its hook with
# CLAUDE_PROJECT_DIR set to a throwaway repo, and checks the Stop hook's config.
# Run by scripts/validate.sh. Exit 0 = all pass, 1 = a check failed.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES
plugin="$(cd "$(dirname "$0")/../.." && pwd)/plugins/decision-log"
hook="$plugin/hooks/scripts/session-start.sh"
sh_bin=bash; [ -x /bin/bash ] && sh_bin=/bin/bash
tmp="$(mktemp -d "${TMPDIR:-/tmp}/decision-log-test.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT; [ -n "${KEEP:-}" ] && echo "fixture: $tmp"
fails=0; checks=0

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
r="$tmp/repo"; mkdir -p "$r" && cd "$r" || exit 1
git init -q && git symbolic-ref HEAD refs/heads/main
git config user.email t@example.com; git config user.name t
git config commit.gpgsign false; git config core.hooksPath /dev/null
echo x > a.txt && git add -A && git commit -qm init
git checkout -q -b feat/a-b

run() { printf '{"source":"%s"}' "$1" | CLAUDE_PROJECT_DIR="$2" "$sh_bin" "$hook" 2>&1; }
has() { checks=$((checks + 1)); printf '%s\n' "$out" | grep -qF -- "$2" || { echo "FAIL: $1: missing: $2"; fails=$((fails + 1)); }; }
lacks() { checks=$((checks + 1)); printf '%s\n' "$out" | grep -qF -- "$2" && { echo "FAIL: $1: unexpected: $2"; fails=$((fails + 1)); }; }
ok() { checks=$((checks + 1)); eval "$2" || { echo "FAIL: $1"; fails=$((fails + 1)); }; }

D=.harness/decisions; mkdir -p "$D"
printf '# Decisions: feat/a-b\r\n\n## 2026-10-20: fetch over axios\n- Over: axios\n- Why: no new dependency\n- Files: a.txt\n\n## 2026-10-21: retry twice\n- Over: no retry\n- Why: the API drops 1%% of calls\n- Files: none yet\n' > "$D/feat__a-b.md"
printf '# Decisions: old/gone\n\n## 2026-09-01: something\n' > "$D/old__gone.md"
printf 'scratch notes, no header\n' > "$D/notes.md"
printf '# Decisions: other/y\n' > "$D/other__x.md"

out="$(run startup "$r")"; code=$?
ok "exit 0" '[ "$code" -eq 0 ]'
has "branch log named, slash as __" '`.harness/decisions/feat__a-b.md`: 2 decision(s) on `feat/a-b`'
has "entries shown" "- Why: the API drops 1% of calls"
has "entry headings sit under the section" "### 2026-10-21: retry twice"
ok "header line not repeated" '! printf "%s\n" "$out" | grep -q "^# Decisions:"'
has "how to log, for this branch" 'append it to `.harness/decisions/feat__a-b.md`'
lacks "no compaction note at startup" "just compacted"
has "deleted branch's log archived" 'its log moved to .harness/decisions/archive/: `old/gone`'
ok "archived file moved" '[ ! -e "$D/old__gone.md" ] && ls "$D"/archive/old__gone-*.md >/dev/null 2>&1'
ok "existing branch's log kept (CRLF header)" '[ -f "$D/feat__a-b.md" ]'
ok "file without a header left alone" '[ -f "$D/notes.md" ]'
ok "header naming another file's branch left alone" '[ -f "$D/other__x.md" ]'

out="$(run compact "$r")"
has "after compaction, asks for decisions the summary has" "Context was just compacted"
lacks "archives once" "its log moved"

i=0; while [ $i -lt 30 ]; do printf '\n## 2026-10-22: d%s\n- Why: w%s\n' "$i" "$i"; i=$((i + 1)); done >> "$D/feat__a-b.md"
out="$(run startup "$r")"
has "long log: titles only" "Titles (read the file for the reasons):"
has "long log: titles listed" "- 2026-10-22: d29"
lacks "long log: bodies left out" "- Why: w29"
while [ $i -lt 70 ]; do printf '\n## 2026-10-22: d%s\n' "$i"; i=$((i + 1)); done >> "$D/feat__a-b.md"
out="$(run startup "$r")"
has "longer log: the newest titles" "Newest 60 of 72 titles"
has "longer log: newest kept" "- 2026-10-22: d69"
lacks "longer log: oldest dropped" "fetch over axios"
why="$(i=0; while [ $i -lt 90 ]; do printf 'because '; i=$((i + 1)); done)"
{ printf '# Decisions: feat/a-b\n'; i=0; while [ $i -lt 12 ]; do printf '\n## 2026-10-23: e%s\n- Why: %s\n' "$i" "$why"; i=$((i + 1)); done; } > "$D/feat__a-b.md"
out="$(run compact "$r")"
has "big entries: titles only" "Titles (read the file for the reasons):"
lacks "big entries: bodies left out" "because because"
long="$(i=0; while [ $i -lt 25 ]; do printf 'long title '; i=$((i + 1)); done)"
{ printf '# Decisions: feat/a-b\n'; i=0; while [ $i -lt 40 ]; do printf '## 2026-10-23: t%s %s\n' "$i" "$long"; i=$((i + 1)); done; } > "$D/feat__a-b.md"
out="$(run compact "$r")"
ok "long titles stay under the 10K context cap" '[ "${#out}" -lt 9000 ]'
has "long titles: instructions survive" "Context was just compacted"
has "long titles: cut, with a pointer" "... (cut here; the rest is in .harness/decisions/feat__a-b.md)"
printf '# Decisions: `feat/a-b` (T-12)\n\n## 2026-10-23: x\n' > "$D/feat__a-b.md"
out="$(run startup "$r")"
ok "current branch's log kept, even with a decorated header" '[ -f "$D/feat__a-b.md" ]'

git checkout -q main
out="$(run startup "$r")"
ok "another existing branch's log kept" '[ -f "$D/feat__a-b.md" ]'
has "branch without a log" 'No decisions logged on `main` yet (`.harness/decisions/main.md`)'
git checkout -q --detach HEAD
out="$(run startup "$r")"
has "detached HEAD" "HEAD is detached"
u="$tmp/unborn"; mkdir -p "$u/.harness/decisions" && git -C "$u" init -q && git -C "$u" symbolic-ref HEAD refs/heads/main
printf '# Decisions: main\n\n## 2026-10-23: plan first\n' > "$u/.harness/decisions/main.md"
out="$(run compact "$u")"
ok "unborn branch's log kept" '[ -f "$u/.harness/decisions/main.md" ]'
has "unborn branch's log loaded" '1 decision(s) on `main`'
mkdir -p "$tmp/plain"
out="$(run startup "$tmp/plain")"; code=$?
ok "outside a repo: silent, exit 0" '[ "$code" -eq 0 ] && [ -z "$out" ]'

# The Stop check is a prompt hook, so only its wiring is checked here; scripts/tests/live/
# runs it for real. It must see the hook input, let a stop through once a Stop hook has
# continued the turn (or it could loop), and in plan mode.
stop="$(jq -r '.hooks.Stop[0].hooks[0] | select(.type == "prompt") | .prompt' "$plugin/hooks/hooks.json")"
for term in '$ARGUMENTS' stop_hook_active permission_mode '"plan"' .harness/decisions/; do
  ok "Stop prompt mentions $term" 'printf "%s" "$stop" | grep -qF -- "$term"'
done

if [ "$fails" -gt 0 ]; then echo "decision-log: $fails of $checks checks failed"; exit 1; fi
echo "decision-log: $checks checks passed"
