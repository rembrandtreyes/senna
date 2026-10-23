#!/usr/bin/env bash
# Fixture test for plugins/pr-story/skills/pr-story/scripts/pr-facts.sh. Builds a throwaway
# git repo, runs the script under the system bash (3.2 on macOS), and checks exact lines.
# Run by scripts/validate.sh. Exit 0 = all pass, 1 = a check failed.
set -uo pipefail
# A git hook exports GIT_DIR and friends; inherited, they would point the fixture's git
# commands (init, config, commit) at the caller's repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES
script="$(cd "$(dirname "$0")/../.." && pwd)/plugins/pr-story/skills/pr-story/scripts/pr-facts.sh"
sh_bin=bash; [ -x /bin/bash ] && sh_bin=/bin/bash
tmp="$(mktemp -d "${TMPDIR:-/tmp}/pr-facts-test.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT; [ -n "${KEEP:-}" ] && echo "fixture: $tmp"
fails=0; checks=0

# Isolate the fixture from the user's git config (signing, hooks, default branch). A UTF-8
# locale is where invalid bytes used to abort awk.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 LANG=en_US.UTF-8
r="$tmp/repo"; mkdir -p "$r" && cd "$r" || exit 1
git init -q && git symbolic-ref HEAD refs/heads/main
git config user.email t@example.com; git config user.name t
git config commit.gpgsign false; git config core.hooksPath /dev/null
# Config that changes diff and log output must not change the facts.
git config diff.noprefix true; git config color.ui always; git config log.showSignature true

commit() { git add -A && git commit -qm "$1"; }
run() { "$sh_bin" "$script" "$@" 2>&1; }
has() { checks=$((checks + 1)); printf '%s\n' "$out" | grep -qF -- "$2" || { echo "FAIL: $1: missing: $2"; fails=$((fails + 1)); }; }
lacks() { checks=$((checks + 1)); printf '%s\n' "$out" | grep -qF -- "$2" && { echo "FAIL: $1: unexpected: $2"; fails=$((fails + 1)); }; }
code_is() { checks=$((checks + 1)); [ "$code" -eq "$2" ] || { echo "FAIL: $1: exit $code, expected $2"; fails=$((fails + 1)); }; }

mkdir -p tasks "my lib" "{{t}}" specs/inv/adr .harness plugins/a shared
printf 'package lib\n' > lib.go
printf -- '-- rotate the secret\nselect 1;\n' > z.sql
printf 'flask==2.0\n' > requirements.txt
printf '{"lockfileVersion": 3}\n' > package-lock.json
printf 'const a = 1\n' > 'x => y.ts'
printf 'l1\nl2\nl3\nl4\nl5\n' > '{{t}}/old.py'
printf '# T-012: invites\n\nStatus: review   # todo\r\nRequirements: R-3\r\nSpec: specs/inv/spec.md\n' > tasks/T-012-invites.md
printf 'Status: todo\n' > tasks/T-013-other.md
printf '# spec\n' > specs/inv/spec.md; printf '# ADR\n' > specs/inv/adr/0001-pick.md
printf -- '- 2026-10-01 [review] z.sql: who runs the migration?\n- 2026-10-02 [testing] use the real db\n' > .harness/learnings.md
printf '.harness/decisions/\n' > .gitignore
commit "init"
echo '// a' >> lib.go; commit "fix: lib panics on empty input"
echo '// b' >> lib.go; commit "Revert \"feat: lib cache\""
echo '// c' >> lib.go; commit "fixtures: add sample data"

git checkout -q -b feat/T-12-invites
printf 'nom=caf\351\n' > a-legacy.properties
printf 'const r = await fetch("/x")\n' > "my lib/client.ts"
printf 'flask==3.0\n' > requirements.txt
printf '{"lockfileVersion": 3, "packages": {"atomic-sleep": "1.0"}}\n' > package-lock.json
printf 'select 1;\ngrant all;\n' > z.sql
printf 'await fetch(u)\n' >> 'x => y.ts'
git mv '{{t}}/old.py' '{{t}}/new.py' && echo l6 >> '{{t}}/new.py'
mkdir -p pkg src/authorization skills/demo && git mv lib.go pkg/lib.go && echo '// d' >> pkg/lib.go
printf 'package roles\n' > src/authorization/roles.go
printf -- '---\nname: demo\n---\n' > skills/demo/SKILL.md
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do echo "line $i"; done > plugins/a/common.sh
cp plugins/a/common.sh shared/common.sh
# Sign it when ssh-keygen exists: with log.showSignature, git prints signature lines to stdout.
sign=""; if command -v ssh-keygen >/dev/null && ssh-keygen -q -t ed25519 -N "" -f "$tmp/key" >/dev/null 2>&1; then
  git config gpg.format ssh; git config user.signingkey "$tmp/key.pub"; sign=-S
fi
git add -A && git commit -q ${sign:+"$sign"} -m "feat: invites (T-12)" -m "Follows T-13." \
  -m "Decision: fetch over axios: no new dependency"
mkdir -p .harness/decisions
printf '# Decisions: feat/T-12-invites\n\n## 2026-10-20: fetch over axios\n- Why: no new dependency\n\n## 2026-10-21: one table\n- Why: simpler\n' > .harness/decisions/feat__T-12-invites.md
idx_before="$(cksum < .git/index)"
echo dirty > untracked.txt

out="$(run main)"
has "space in path keeps content tags (after a non-UTF-8 line)" "my lib/client.ts  [http]"
has "manifest before docs rule" "requirements.txt  [config]"
lacks "lockfile gets no content tags" "package-lock.json  ["
has "lockfile and copy not counted" "not counted: 2 lockfile/generated/asset/duplicate file(s), 14 lines"
has "synced copy named" "shared/common.sh (same content as plugins/a/common.sh)"
has "removed -- line is content, not a header" "z.sql  [data security]"
has "rename keeps fix history" "pkg/lib.go: 2 fix commits (1 revert)"
has "history lists the fix commits" "fix: lib panics on empty input"
has "rename shown" "lib.go -> pkg/lib.go"
has "=> in a filename isn't a rename" "x => y.ts  [http]"
has "braces in a renamed path" "{{t}}/old.py -> {{t}}/new.py"
has "authoriz path is security" "src/authorization/roles.go  [security]"
has "skill files are prompts" "skills/demo/SKILL.md  [prompt]"
has "checklists from tags" "checklists: core, http, data, security, config"
has "branch ref first" "refs: T-12 T-13"
has "branch T-number beats a body ref; CRLF stripped" "task: tasks/T-012-invites.md (Status: review; Requirements: R-3)"
has "spec from the task" "spec: specs/inv/spec.md"
has "ADRs next to the spec" "adrs: specs/inv/adr/0001-pick.md"
has "lessons counted" "lessons: .harness/learnings.md, 1 [review] of 2 entries"
has "branch decision log" "decisions: .harness/decisions/feat__T-12-invites.md, 2 logged"
has "decision trailers" "decision trailers: 1 in this branch's commits"
has "uncommitted counted" "uncommitted: 1 file(s)"
has "branch name" "branch: feat/T-12-invites"
lacks "no signature lines" "No signature"
checks=$((checks + 1)); [ "$(cksum < .git/index)" = "$idx_before" ] || { echo "FAIL: read-only: .git/index changed"; fails=$((fails + 1)); }

out="$(PR_STORY_MAX_LINES=3 run main)"
has "size limit" "limit 3: OVER"
out="$(PR_STORY_MAX_LINES=abc run main)"
has "bad limit falls back" "limit 400: ok"

head_sha="$(git rev-parse HEAD)"
git checkout -q -b feat/t-13-lower
out="$(run main)"
has "lowercase branch T-number" "task: tasks/T-013-other.md"
lacks "another branch's decision log isn't used" "decisions: .harness/"
printf ' tasks/T-012-invites.md \r\n' > .harness/current-task
out="$(run main)"
has "current-task wins, trimmed" "task: tasks/T-012-invites.md"
printf '/etc/hosts\n' > .harness/current-task
out="$(run main)"
has "current-task outside the repo ignored" "current-task ignored"
rm -f .harness/current-task

git checkout -q main
out="$(run main "$head_sha")"
has "head argument describes a branch that isn't checked out" "my lib/client.ts  [http]"
has "head argument finds the task in the commit" "task: tasks/T-012-invites.md"
lacks "no uncommitted line for another head" "uncommitted:"
out="$(run main "$head_sha" feat/T-12-invites)"
has "branch name argument" "branch: feat/T-12-invites"
has "branch name argument finds its decision log" "decisions: .harness/decisions/feat__T-12-invites.md"
printf '# Decisions: main\n\n## 2026-10-23: ours\n' > .harness/decisions/main.md
out="$(run main "$head_sha" main)"
lacks "a fork's branch named main doesn't get our log" "decisions: .harness/decisions/main.md"
rm -f .harness/decisions/main.md

git checkout -q -b noop main && echo x >> z.sql && commit "x" && git revert --no-edit HEAD >/dev/null
out="$(run main)"
has "net-empty branch" "no net change against the base"

git checkout -q -b mrg main && git checkout -q main && echo m > m.txt && commit "m" && git checkout -q mrg
git merge -q --no-ff --no-commit main >/dev/null 2>&1; echo evil > evil.go; git add -A; git commit -qm "merge main"
out="$(run main)"
has "merge-only change still described" "evil.go"

git checkout -q --detach "$head_sha"
out="$(run main)"
has "detached head" "branch: (detached)"

git checkout -q -b trailers main
echo t1 >> z.sql && git commit -qam "t1" -m "Decision: a over b: c"
echo t2 >> z.sql && git commit -qam "t2" -m "$(printf 'Decision: a over b: c\nDecision: d over e:\n  because f')"
out="$(run main)"
has "trailers unfolded and counted once" "decision trailers: 2 in this branch's commits"

git clone -q --depth 1 --no-single-branch "file://$r" "$tmp/shallow" 2>/dev/null
out="$(cd "$tmp/shallow" && git checkout -q feat/T-12-invites && run origin/main)"; code=$?
code_is "shallow clone exits 2" 2; has "shallow clone named" "shallow clone"

out="$(run nope)"; code=$?
code_is "unknown ref" 2
out="$(cd .git && run main)"; code=$?
code_is "inside .git" 2
out="$(cd "$tmp" && run)"; code=$?
code_is "outside a repo" 2

if [ "$fails" -gt 0 ]; then echo "pr-facts: $fails of $checks checks failed"; exit 1; fi
echo "pr-facts: $checks checks passed"
