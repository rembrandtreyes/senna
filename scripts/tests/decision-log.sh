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

D=.harness/decisions; F="$D/feat__a-b"; mkdir -p "$F" "$D/old__gone" "$D/drafts" "$D/other__y"
printf '# fetch over axios\r\n- Date: 2026-10-20\r\n- Over: axios\r\n- Why: no new dependency\r\n- Files: a.txt\r\n' > "$F/001-fetch-over-axios.md"
printf '# one table\n- Date: 2026-10-21\n- Why: simpler\n' > "$F/002-one-table.md"
printf '# two tables\n- Date: 2026-10-22\n- Over: one table\n- Why: the API drops 1%% of calls\n- Replaces: 002 (one table, 2026-10-21)\n\n## Notes\nretry twice\n' > "$F/003-two-tables.md"
printf '# 004: retry twice\n- Why: flaky API\n- Replaces: none\n' > "$F/004-retry-twice.md"
printf 'scratch\n' > "$F/notes.md"
printf '# something\n' > "$D/old__gone/001-something.md"
printf '# theirs\n' > "$D/other__y/001-theirs.md"
printf 'no decisions here\n' > "$D/drafts/plan.md"
git branch other/y

out="$(run startup "$r")"; code=$?
ok "exit 0" '[ "$code" -eq 0 ]'
has "branch folder named, slash as __" '`.harness/decisions/feat__a-b/`: 4 decision(s) on `feat/a-b`'
has "index from the files" "- 001 fetch over axios"
ok "CR stripped from a CRLF file" '! printf "%s\n" "$out" | grep -q "$(printf "\r")"'
has "replaced decision marked" "- 002 one table (replaced by 003)"
has "reversal marked, by its number only" "- 003 two tables (replaces 002)"
has "a number repeated in the title is dropped" "- 004 retry twice"
lacks "Replaces: none is no reversal" "(replaces none)"
lacks "a file that isn't a decision isn't listed" "scratch"
has "newest in full" "### 003 two tables"
has "newest in full: body" "- Why: the API drops 1% of calls"
has "heading inside a decision demoted" "#### Notes"
lacks "a replaced decision isn't shown in full" "### 002"
has "how to log, for this branch" '`.harness/decisions/feat__a-b/NNN-<slug>.md`'
lacks "no compaction note at startup" "just compacted"
has "deleted branch's folder archived" 'its decisions moved to .harness/decisions/archive/: `old__gone`'
ok "archived folder moved" '[ ! -e "$D/old__gone" ] && ls "$D"/archive/old__gone-*/001-something.md >/dev/null 2>&1'
ok "folder without decisions left alone" '[ -f "$D/drafts/plan.md" ]'
ok "another existing branch's folder kept" '[ -d "$D/other__y" ]'
ok "current branch's folder kept" '[ -f "$F/001-fetch-over-axios.md" ]'

out="$(run compact "$r")"
has "after compaction, asks for decisions the summary has" "Context was just compacted"
lacks "archives once" "its decisions moved"
git tag feat/a-b
out="$(run startup "$r")"
has "a tag named like the branch: same folder" '`.harness/decisions/feat__a-b/`: 4 decision(s) on `feat/a-b`'
git tag -d feat/a-b >/dev/null

printf '# nine\n' > "$F/9-nine.md"; printf '# ten\n' > "$F/10-ten.md"
out="$(run startup "$r")"
ok "numbers sort as numbers" 'printf "%s\n" "$out" | grep -E "^- (9|10) " | head -n 1 | grep -q "^- 9 nine"'
lacks "only the leading number of Replaces counts" "- 10 ten (replaced"
rm -f "$F"/*.md
i=1; while [ $i -le 72 ]; do printf '# d%s\n- Why: w%s\n' "$i" "$i" > "$F/$(printf %03d $i)-d$i.md"; i=$((i + 1)); done
out="$(run startup "$r")"
has "long log: the newest titles" "Newest 60 of 72 decisions"
has "long log: newest kept" "- 072 d72"
lacks "long log: oldest dropped" "- 012 d12"
has "long log: index kept" "- 013 d13"
lacks "long log: only listed decisions in full" "### 012 d12"
why="$(i=0; while [ $i -lt 90 ]; do printf 'because '; i=$((i + 1)); done)"
rm -f "$F"/*.md
i=1; while [ $i -le 12 ]; do printf '# e%s\n- Why: %s\n' "$i" "$why" > "$F/$(printf %03d $i)-e$i.md"; i=$((i + 1)); done
{ printf '# huge\n'; i=0; while [ $i -lt 10 ]; do printf -- '- Why: %s\n' "$why"; i=$((i + 1)); done; } > "$F/013-huge.md"
out="$(run compact "$r")"
lacks "big decisions: one too big to show is skipped" "### 013 huge"
has "big decisions: the newest in full" "### 012 e12"
lacks "big decisions: only what fits" "### 001 e1"
has "big decisions: all titles" "- 001 e1"
ok "big decisions stay under the 10K context cap" '[ "${#out}" -lt 9000 ]'
long="$(i=0; while [ $i -lt 25 ]; do printf 'long title '; i=$((i + 1)); done)"
rm -f "$F"/*.md
i=1; while [ $i -le 40 ]; do printf '# t%s %s\n' "$i" "$long" > "$F/$(printf %03d $i)-t$i.md"; i=$((i + 1)); done
out="$(run compact "$r")"
ok "long titles stay under the 10K context cap" '[ "${#out}" -lt 9000 ]'
has "long titles: instructions survive" "Context was just compacted"
has "long titles: the index keeps the newest" "- 040 t40"
has "long titles: says how many it shows" "of 40 decisions (the rest are in the folder)"
lacks "long titles: the oldest go" "- 001 t1 "
ok "long titles: shortened to 160 bytes" 'l="$(printf "%s\n" "$out" | grep "^- 040 t40 ")"; [ "${#l}" -eq 160 ] && [ "${l%...}" != "$l" ]'
printf '# p %s%s%s\n' "$long" "$long" "$long" > "$F/041-pasted.md"
out="$(run startup "$r")"
has "one huge title doesn't hide the rest" "- 040 t40"
e="$(i=0; while [ $i -lt 100 ]; do printf '\303\251'; i=$((i + 1)); done)"
printf '# %s\n' "$e" > "$F/043-accents.md"
out="$(run startup "$r")"
ok "a shortened title keeps whole UTF-8 characters" 'l="$(printf "%s\n" "$out" | grep "^- 043 ")"; printf "%s" "$l" | grep -q "^- 043 éééé" && printf "%s\n" "$l" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1'
printf -- '- Date: 2026-10-23\n' > "$F/042-no-title-line.md"
rm -f "$F"/0[0-3]*.md
out="$(run startup "$r")"
has "no title line: the name stands in" "- 042 no title line"

git checkout -q main
out="$(run startup "$r")"
ok "on main, the feature branch's folder kept" '[ -d "$F" ]'
has "branch without decisions" 'No decisions logged on `main` yet (`.harness/decisions/main/`)'
git checkout -q --detach HEAD
out="$(run startup "$r")"
has "detached HEAD" "HEAD is detached"
ok "detached HEAD: branch folders kept" '[ -d "$F" ] && [ -d "$D/other__y" ]'
u="$tmp/unborn"; mkdir -p "$u/.harness/decisions/main" && git -C "$u" init -q && git -C "$u" symbolic-ref HEAD refs/heads/main
printf '# plan first\n' > "$u/.harness/decisions/main/001-plan-first.md"
out="$(run compact "$u")"
ok "unborn branch's folder kept" '[ -f "$u/.harness/decisions/main/001-plan-first.md" ]'
has "unborn branch's folder loaded" '1 decision(s) on `main`'
# Over 64K of branch names, grep -q in a pipe under pipefail used to archive a live folder.
b="$tmp/big"; mkdir -p "$b/.harness/decisions/aaa__live" && cd "$b" && git init -q && git symbolic-ref HEAD refs/heads/main
git commit -q --allow-empty -m init && git branch aaa/live && sha="$(git rev-parse HEAD)"
i=0; while [ $i -lt 3000 ]; do printf 'create refs/heads/zz/branch-with-a-fairly-long-name-%05d %s\n' $i "$sha"; i=$((i + 1)); done | git update-ref --stdin
printf '# keep me\n' > .harness/decisions/aaa__live/001-keep-me.md
i=1; while [ $i -le 7 ]; do mkdir -p ".harness/decisions/gone__$i" && printf '# x\n' > ".harness/decisions/gone__$i/001-x.md"; i=$((i + 1)); done
out="$(run startup "$b")"
ok "many branches: a live folder is kept" '[ -f "$b/.harness/decisions/aaa__live/001-keep-me.md" ]'
has "many archived: the list is capped" "and 2 more"
lacks "many archived: names past five left out" '`gone__7`'
cd "$r" || exit 1
mkdir -p "$tmp/plain"
out="$(run startup "$tmp/plain")"; code=$?
ok "outside a repo: silent, exit 0" '[ "$code" -eq 0 ] && [ -z "$out" ]'

# The Stop check is a prompt hook, so only its wiring is checked here; scripts/tests/live/
# runs it for real. It must see the hook input, let a stop through once a Stop hook has
# continued the turn (or it could loop), and in plan mode.
stop="$(jq -r '.hooks.Stop[0].hooks[0] | select(.type == "prompt") | .prompt' "$plugin/hooks/hooks.json")"
for term in '$ARGUMENTS' stop_hook_active permission_mode '"plan"' .harness/decisions/ NNN-; do
  ok "Stop prompt mentions $term" 'printf "%s" "$stop" | grep -qF -- "$term"'
done

if [ "$fails" -gt 0 ]; then echo "decision-log: $fails of $checks checks failed"; exit 1; fi
echo "decision-log: $checks checks passed"
