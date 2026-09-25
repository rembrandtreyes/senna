#!/usr/bin/env bash
# Stop: SLOW checks, only if TS/JS files changed.
#   interactive: typecheck
#   parallel/auto: typecheck + tests
# Project override: .harness/checks/ts-stop.sh
source "$(dirname "$0")/common.sh"

changed="$(changed_files ts tsx js jsx mjs cjs mts cts)"
[ -n "$changed" ] || { stop_passed ts; exit 0; }
root="$(project_dir)"

if run_override ts-stop; then finish_stop ts; fi

pm_for() {
  local d
  d="$(find_up "$1" pnpm-lock.yaml)" && { echo pnpm; return; }
  d="$(find_up "$1" bun.lockb)" && { echo bun; return; }
  d="$(find_up "$1" bun.lock)" && { echo bun; return; }
  d="$(find_up "$1" yarn.lock)" && { echo yarn; return; }
  echo npm
}

tsdirs=""; pkgdirs=""
while IFS= read -r f; do
  case "$f" in */node_modules/*|*/dist/*|*/.next/*) continue ;; esac
  d="$(dirname "$f")"
  t="$(find_up "$d" tsconfig.json)" && case " $tsdirs " in *" $t "*) ;; *) tsdirs="$tsdirs $t" ;; esac
  p="$(find_up "$d" package.json)" && case " $pkgdirs " in *" $p "*) ;; *) pkgdirs="$pkgdirs $p" ;; esac
done <<< "$changed"

for t in $tsdirs; do
  tsc=""
  for d in "$t" "$root"; do [ -x "$d/node_modules/.bin/tsc" ] && { tsc="$d/node_modules/.bin/tsc"; break; }; done
  [ -n "$tsc" ] && run_check "typecheck" "$t" "$tsc" --noEmit -p .
done

if is_strict; then
  for p in $pkgdirs; do
    has_test="$(jq -r '.scripts.test // empty' "$p/package.json" 2>/dev/null)"
    [ -n "$has_test" ] || continue
    case "$has_test" in *"no test specified"*) continue ;; esac
    pm="$(pm_for "$p")"
    run_check "tests" "$p" env CI=true "$pm" run test
  done
fi

finish_stop ts
