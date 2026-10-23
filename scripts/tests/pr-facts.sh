#!/usr/bin/env bash
# Fixture test for plugins/pr-story/skills/pr-story/scripts/pr-facts.sh. Builds a throwaway
# git repo, runs the script under the system bash (3.2 on macOS), and checks exact lines.
# Run by scripts/validate.sh. Exit 0 = all pass, 1 = a check failed.
set -uo pipefail
script="$(cd "$(dirname "$0")/../.." && pwd)/plugins/pr-story/skills/pr-story/scripts/pr-facts.sh"
sh_bin=bash; [ -x /bin/bash ] && sh_bin=/bin/bash
tmp="$(mktemp -d "${TMPDIR:-/tmp}/pr-facts-test.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT; [ -n "${KEEP:-}" ] && echo "fixture: $tmp"
fails=0; checks=0

# Isolate the fixture from the user's git config (signing, hooks, default branch).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
r="$tmp/repo"; mkdir -p "$r" && cd "$r" || exit 1
git init -q && git symbolic-ref HEAD refs/heads/main
git config user.email t@example.com; git config user.name t
git config commit.gpgsign false; git config core.hooksPath /dev/null
# Config that changes diff output must not change the facts.
git config diff.noprefix true; git config color.ui always

commit() { git add -A && git commit -qm "$1"; }
run() { "$sh_bin" "$script" "$@" 2>&1; }
has() { checks=$((checks + 1)); printf '%s\n' "$out" | grep -qF -- "$2" || { echo "FAIL: $1: missing: $2"; fails=$((fails + 1)); }; }
lacks() { checks=$((checks + 1)); printf '%s\n' "$out" | grep -qF -- "$2" && { echo "FAIL: $1: unexpected: $2"; fails=$((fails + 1)); }; }

mkdir -p tasks "my lib"
printf 'package lib\n' > lib.go
printf -- '-- keep\nselect 1;\n' > z.sql
printf 'flask==2.0\n' > requirements.txt
printf '{"lockfileVersion": 3}\n' > package-lock.json
printf '# T-012: invites\n\nStatus: review   # todo\nRequirements: R-3\n' > tasks/T-012-invites.md
commit "init"
echo '// a' >> lib.go; commit "fix: lib panics on empty input"
echo '// b' >> lib.go; commit "Revert \"feat: lib cache\""
echo '// c' >> lib.go; commit "fixtures: add sample data"

git checkout -q -b feat/T-12-invites
printf 'const r = await fetch("/x")\n' > "my lib/client.ts"
printf 'flask==3.0\n' > requirements.txt
printf '{"lockfileVersion": 3, "packages": {"atomic-sleep": "1.0"}}\n' > package-lock.json
printf 'select 1;\ngrant password;\n' > z.sql
mkdir -p pkg && git mv lib.go pkg/lib.go && echo '// d' >> pkg/lib.go
commit "feat: invites (T-12)"
idx_before="$(cksum < .git/index)"
echo dirty > untracked.txt

out="$(run main)"
has "space in path keeps content tags" "my lib/client.ts  [http]"
has "manifest before docs rule" "requirements.txt  [config]"
lacks "lockfile gets no content tags" "package-lock.json  ["
has "lockfile not counted" "package-lock.json"
has "removed -- line is content" "z.sql  [data security]"
has "rename keeps fix history" "pkg/lib.go: 2 fix commits (1 revert)"
has "rename shown" "lib.go -> pkg/lib.go"
has "zero-padded task from T-12 ref" "task: tasks/T-012-invites.md (Status: review; Requirements: R-3)"
has "uncommitted counted" "uncommitted: 1 file(s)"
has "branch name" "branch: feat/T-12-invites"
checks=$((checks + 1)); [ "$(cksum < .git/index)" = "$idx_before" ] || { echo "FAIL: read-only: .git/index changed"; fails=$((fails + 1)); }

out="$(PR_STORY_MAX_LINES=3 run main)"
has "size limit" "limit 3: OVER"

head_sha="$(git rev-parse HEAD)"
git checkout -q main
out="$(run main "$head_sha")"
has "head argument describes a branch that isn't checked out" "my lib/client.ts  [http]"
has "head argument finds the task in the commit" "task: tasks/T-012-invites.md"
lacks "no uncommitted line for another head" "uncommitted:"

git checkout -q -b noop main && echo x >> z.sql && commit "x" && git revert --no-edit HEAD >/dev/null
out="$(run main)"
has "net-empty branch" "no net change against the base"

git checkout -q --detach "$head_sha"
out="$(run main)"
has "detached head" "branch: (detached)"

out="$(run nope)"; code=$?
checks=$((checks + 1)); [ "$code" -eq 2 ] || { echo "FAIL: unknown ref exits 2, got $code"; fails=$((fails + 1)); }
out="$(cd "$tmp" && run)"; code=$?
checks=$((checks + 1)); [ "$code" -eq 2 ] || { echo "FAIL: outside a repo exits 2, got $code"; fails=$((fails + 1)); }

if [ "$fails" -gt 0 ]; then echo "pr-facts: $fails of $checks checks failed"; exit 1; fi
echo "pr-facts: $checks checks passed"
