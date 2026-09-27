#!/usr/bin/env bash
# Stop: only if .go files changed.
#   interactive: go build + go vet (per affected module)
#   parallel/auto: + go test (extra flags via HARNESS_GO_TEST_FLAGS, e.g. "-race")
# Override: .harness/checks/go-stop.sh
source "$(dirname "$0")/common.sh"
has go || exit 0

changed="$(changed_files go)"
[ -n "$changed" ] || { stop_passed go; exit 0; }

# Source changed with no test change: ask once (skipped if the project has no Go tests yet).
src=""; tst=""
while IFS= read -r f; do
  case "$f" in
    */vendor/*|*.pb.go|*_gen.go) ;;
    *_test.go) tst="$tst$f
" ;;
    *) src="$src$f
" ;;
  esac
done <<< "$changed"
has_tests="$(git -C "$(project_dir)" ls-files '*_test.go' 2>/dev/null | head -n1)"
test_nudge go "${src%
}" "$tst" "$has_tests"

if run_override go-stop; then finish_stop go; fi

mods=""
while IFS= read -r f; do
  case "$f" in */vendor/*) continue ;; esac
  m="$(find_up "$(dirname "$f")" go.mod)" || continue
  case " $mods " in *" $m "*) ;; *) mods="$mods $m" ;; esac
done <<< "$changed"

for m in $mods; do
  run_check "go build" "$m" go build ./...
  run_check "go vet" "$m" go vet ./...
  if is_strict; then
    # shellcheck disable=SC2086
    run_check "go test" "$m" go test ${HARNESS_GO_TEST_FLAGS:-} ./...
  fi
done

finish_stop go
