#!/usr/bin/env bash
# Fixture test for lang-ts's Stop hook typecheck: which tsconfig it checks each changed project
# with, and what it reports. A fake tsc logs its folder and arguments and fails on a config that
# contains "fake-error". Pipes hook JSON into the hook with CLAUDE_PROJECT_DIR set to a throwaway
# repo.
# Run by scripts/validate.sh. Exit 0 = all pass, 1 = a check failed.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES HARNESS_MODE HARNESS_TEST_NUDGE \
  CLAUDE_PROJECT_DIR
hook="$(cd "$(dirname "$0")/../.." && pwd)/plugins/lang-ts/hooks/scripts/on-stop.sh"
sh_bin=bash; [ -x /bin/bash ] && sh_bin=/bin/bash
tmp="$(mktemp -d "${TMPDIR:-/tmp}/lang-ts-stop-test.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT
[ -n "${KEEP:-}" ] && echo "fixture: $tmp"
fails=0; checks=0

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 HOME="$tmp/home" TSC_LOG="$tmp/tsc.log"
mkdir -p "$tmp/repo" "$HOME" && cd "$tmp/repo" || exit 1
r="$(pwd -P)"
git init -q && git symbolic-ref HEAD refs/heads/main
git config user.email t@example.com; git config user.name t; git config commit.gpgsign false
mkdir -p node_modules/.bin apps/a/src apps/b/src
cat > node_modules/.bin/tsc <<'EOF'
#!/bin/sh
printf '%s|%s\n' "$PWD" "$*" >> "$TSC_LOG"
cfg=.; prev=; for a in "$@"; do [ "$prev" = -p ] && cfg="$a"; prev="$a"; done
[ -d "$cfg" ] && cfg="$cfg/tsconfig.json"
if grep -q fake-error "$cfg"; then echo "$cfg(1,1): error TS6059: fake"; exit 2; fi
exit 0
EOF
chmod +x node_modules/.bin/tsc
echo node_modules/ > .gitignore
# apps/a: tsconfig.json fails (as one whose include reaches past rootDir would); its typecheck
# config passes. apps/b: only a tsconfig.json, which passes.
echo '{"x": "fake-error"}' > apps/a/tsconfig.json
echo '{"extends": "./tsconfig.json"}' > apps/a/tsconfig.typecheck.json
echo '{}' > apps/b/tsconfig.json
echo 'export const a = 1;' > apps/a/src/a.ts
echo 'export const b = 1;' > apps/b/src/b.ts
git add -A && git commit -qm init

ok() { checks=$((checks + 1)); eval "$2" || { echo "FAIL: $1"; fails=$((fails + 1)); }; }
# run : the hook as an interactive Stop; sets code and err, and calls (the fake tsc's log)
run() {
  rm -f "$TSC_LOG"
  err="$(printf '{"hook_event_name":"Stop","stop_hook_active":false}' \
    | CLAUDE_PROJECT_DIR="$r" HARNESS_MODE=interactive "$sh_bin" "$hook" 2>&1 >/dev/null)"
  code=$?
  calls="$(cat "$TSC_LOG" 2>/dev/null)"
}
called() { printf '%s\n' "$calls" | grep -qxF "$r/$1|$2"; }

# Nothing changed: no typecheck.
run
ok "no change: exit 0, tsc not run" '[ "$code" -eq 0 ] && [ -z "$calls" ]'

# A project with a typecheck config is checked with it, not with tsconfig.json.
echo 'export const a = 2;' > apps/a/src/a.ts
run
ok "typecheck config: checked with it" 'called apps/a "--noEmit -p tsconfig.typecheck.json"'
ok "typecheck config: tsconfig.json not checked" '! printf "%s\n" "$calls" | grep -q -- "-p \.$"'
ok "typecheck config: passes, exit 0, quiet" '[ "$code" -eq 0 ] && [ -z "$err" ]'

# Its errors still block, and the report names the config.
echo '{"x": "fake-error"}' > apps/a/tsconfig.typecheck.json
run
ok "typecheck config fails: blocks" '[ "$code" -eq 2 ]'
ok "typecheck config fails: names the config and shows the error" 'printf "%s" "$err" | grep -q "### typecheck (tsconfig.typecheck.json) (in $r/apps/a)" && printf "%s" "$err" | grep -q "error TS6059: fake"'
echo '{"extends": "./tsconfig.json"}' > apps/a/tsconfig.typecheck.json

# A project without one is checked with tsconfig.json, as before.
git checkout -q -- apps/a/src/a.ts
echo 'export const b = 2;' > apps/b/src/b.ts
run
ok "no typecheck config: checked with tsconfig.json" '[ "$calls" = "$r/apps/b|--noEmit -p ." ] && [ "$code" -eq 0 ]'
echo '{"x": "fake-error"}' > apps/b/tsconfig.json
run
ok "no typecheck config, fails: blocks under the old label" '[ "$code" -eq 2 ] && printf "%s" "$err" | grep -q "### typecheck (in $r/apps/b)"'
git checkout -q -- apps/b/tsconfig.json

# Both changed: each project with its own config.
echo 'export const a = 3;' > apps/a/src/a.ts
run
ok "both changed: each with its own config" 'called apps/a "--noEmit -p tsconfig.typecheck.json" && called apps/b "--noEmit -p ." && [ "$(printf "%s\n" "$calls" | wc -l | tr -d " ")" -eq 2 ]'
ok "both changed: exit 0" '[ "$code" -eq 0 ]'

if [ "$fails" -gt 0 ]; then echo "lang-ts-stop: $fails of $checks checks failed"; exit 1; fi
echo "lang-ts-stop: $checks checks passed"
