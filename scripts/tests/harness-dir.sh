#!/usr/bin/env bash
# Fixture test for .harness/ keeping itself out of git: the hooks create it with a .gitignore that
# ignores everything in it, itself included, except what a project commits, so no project needs
# ignore rules. Pipes hook JSON into the hooks with CLAUDE_PROJECT_DIR set to throwaway repos.
# Run by scripts/validate.sh. Exit 0 = all pass, 1 = a check failed.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES HARNESS_MODE
plugins="$(cd "$(dirname "$0")/../.." && pwd)/plugins"
sh_bin=bash; [ -x /bin/bash ] && sh_bin=/bin/bash
tmp="$(mktemp -d "${TMPDIR:-/tmp}/harness-dir-test.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT; [ -n "${KEEP:-}" ] && echo "fixture: $tmp"
fails=0; checks=0
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 HOME="$tmp/home"
mkdir -p "$HOME"

ok() { checks=$((checks + 1)); eval "$2" || { echo "FAIL: $1"; fails=$((fails + 1)); }; }
repo() { mkdir -p "$1" && git -C "$1" init -q && git -C "$1" symbolic-ref HEAD refs/heads/main &&
  git -C "$1" config user.email t@example.com && git -C "$1" config user.name t &&
  git -C "$1" config commit.gpgsign false && echo x > "$1/a.txt" && git -C "$1" add -A &&
  git -C "$1" commit -qm init; }
hook() { printf '%s' "${3:-{\}}" | CLAUDE_PROJECT_DIR="$2" "$sh_bin" "$plugins/$1" >/dev/null 2>&1; }
clean() { [ -z "$(git -C "$1" status --porcelain --untracked-files=all)" ]; }
first="$(printf '%s\n' "$(sed -n "/^HARNESS_GITIGNORE='/{s/^HARNESS_GITIGNORE='//p;q;}" "$plugins/core/hooks/scripts/common.sh")")"

# Not a git repo: session start leaves the folder alone.
mkdir -p "$tmp/plain"; hook core/hooks/scripts/session-start.sh "$tmp/plain" '{"source":"startup"}'
ok "not a git repo: no .harness/" '[ ! -e "$tmp/plain/.harness" ]'

# Session start sets the folder up before Claude writes there.
r="$tmp/repo"; repo "$r"
hook core/hooks/scripts/session-start.sh "$r" '{"source":"startup"}'
ok "session start: .gitignore written" '[ "$(head -n 1 "$r/.harness/.gitignore")" = "$first" ]'
ok "session start: nothing in git status" 'clean "$r"'
H="$r/.harness"; mkdir -p "$H/verdicts" "$H/decisions/main" "$H/vet" "$H/publish/vercel/s"
for f in mode current-task handoff.md handoff-auto.md progress.log ports.env .stop-attempts-ts \
  .gate-x .test-nudge-ts .boundary-warned .deck-stale-s test-audit-2026-10-27.md \
  verdicts/tasks__T-1.md decisions/main/001-x.md vet/pr-3.diff publish/vercel/s/index.html; do
  echo x > "$H/$f"
done
ok "runtime state: nothing in git status" 'clean "$r"'
mkdir -p "$H/checks/nx"
for f in checks/ts-stop.sh checks/boundaries.txt checks/nx/run.sh learnings.md blocked-commands.txt; do
  echo x > "$H/$f"
done
ok "what a project commits shows, the rest doesn't" '[ "$(git -C "$r" status --porcelain --untracked-files=all | sort | tr "\n" " ")" = "?? .harness/blocked-commands.txt ?? .harness/checks/boundaries.txt ?? .harness/checks/nx/run.sh ?? .harness/checks/ts-stop.sh ?? .harness/learnings.md " ]'
ok "committed files add without -f" 'git -C "$r" add .harness/checks .harness/learnings.md .harness/blocked-commands.txt 2>/dev/null'
git -C "$r" commit -qm "project files"

# An older copy of ours is brought up to date; a project's own is left alone.
printf '%s\n*\n' "$first" > "$H/.gitignore"
hook core/hooks/scripts/session-start.sh "$r" '{"source":"startup"}'
ok "an older harness .gitignore is rewritten" 'grep -qxF "!learnings.md" "$H/.gitignore"'
printf '# ours\n*\n!notes.md\n' > "$H/.gitignore"
hook core/hooks/scripts/session-start.sh "$r" '{"source":"startup"}'
ok "a project's own .gitignore is kept" '[ "$(cat "$H/.gitignore")" = "$(printf "# ours\n*\n!notes.md")" ]'

# An existing install: state written before this change, no .gitignore yet.
r2="$tmp/old"; repo "$r2"; mkdir -p "$r2/.harness/verdicts"
echo tasks/T-1.md > "$r2/.harness/current-task"; echo x > "$r2/.harness/verdicts/v"
ok "before: the old state shows" '! clean "$r2"'
hook core/hooks/scripts/session-start.sh "$r2" '{"source":"resume"}'
ok "after session start: it doesn't" 'clean "$r2"'

# Hooks that create the folder on their own, in other plugins too.
r3="$tmp/hooks"; repo "$r3"
hook core/hooks/scripts/pre-compact.sh "$r3" '{"trigger":"manual"}'
ok "pre-compact: handoff written, out of git" '[ -f "$r3/.harness/handoff-auto.md" ] && clean "$r3"'
r4="$tmp/lang"; repo "$r4"
printf '{"stop_hook_active":false}' | CLAUDE_PROJECT_DIR="$r4" "$sh_bin" -c '. "$1"; stop_may_block ts' _ "$plugins/lang-ts/hooks/scripts/common.sh"
ok "lang-ts stop counter: out of git" '[ -f "$r4/.harness/.stop-attempts-ts" ] && clean "$r4"'
r5="$tmp/dl"; repo "$r5"
hook decision-log/hooks/scripts/session-start.sh "$r5" '{"source":"startup"}'
mkdir -p "$r5/.harness/decisions/main" && echo x > "$r5/.harness/decisions/main/001-x.md"
ok "decision-log alone: decisions out of git" 'clean "$r5"'

# worktree.sh: the new worktree's state is out of git, and the shared exclude file is untouched.
r6="$tmp/wt/main"; repo "$r6"
ex="$r6/.git/info/exclude"; before="$(cat "$ex" 2>/dev/null)"
(cd "$r6" && HARNESS_WT_NO_INSTALL=1 "$sh_bin" "$plugins/core/scripts/worktree.sh" feat/x >/dev/null 2>&1)
w="$tmp/wt/main-wt-feat-x"
ok "worktree: ports and mode written" '[ -f "$w/.harness/ports.env" ] && [ "$(cat "$w/.harness/mode")" = parallel ]'
ok "worktree: nothing in git status" 'clean "$w"'
ok "worktree: info/exclude untouched" '[ "$(cat "$ex" 2>/dev/null)" = "$before" ]'

if [ "$fails" -gt 0 ]; then echo "harness-dir: $fails of $checks checks failed"; exit 1; fi
echo "harness-dir: $checks checks passed"
