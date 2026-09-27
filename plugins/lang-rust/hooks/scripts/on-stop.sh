#!/usr/bin/env bash
# Stop: only if .rs files changed.
#   interactive: cargo clippy (or cargo check); stricter lints via HARNESS_CLIPPY_FLAGS="-D warnings"
#   parallel/auto: + cargo test
# Override: .harness/checks/rust-stop.sh
source "$(dirname "$0")/common.sh"
has cargo || exit 0

changed="$(changed_files rs)"
[ -n "$changed" ] || { stop_passed rust; exit 0; }

# Source changed with no test change: ask once (skipped if the project has no Rust tests yet).
# A test change is a file under tests/, or a source file whose change adds a #[test].
src=""; tst=""
while IFS= read -r f; do
  case "$f" in
    */target/*|*/build.rs) continue ;;
    */tests/*) tst="$tst$f
"; continue ;;
  esac
  if { git -C "$(project_dir)" diff HEAD -- "$f" 2>/dev/null | grep '^+' || cat "$f"; } \
      | grep -qE '#\[(tokio::)?test'; then
    tst="$tst$f
"
  else
    src="$src$f
"
  fi
done <<< "$changed"
has_tests="$(git -C "$(project_dir)" grep -l -E '#\[(tokio::)?test' -- '*.rs' 2>/dev/null | head -n1)"
test_nudge rust "${src%
}" "$tst" "$has_tests"

if run_override rust-stop; then finish_stop rust; fi

crates=""
while IFS= read -r f; do
  case "$f" in */target/*) continue ;; esac
  c="$(find_up "$(dirname "$f")" Cargo.toml)" || continue
  case " $crates " in *" $c "*) ;; *) crates="$crates $c" ;; esac
done <<< "$changed"

for c in $crates; do
  if cargo clippy --version >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    run_check "cargo clippy" "$c" cargo clippy --all-targets -q -- ${HARNESS_CLIPPY_FLAGS:-}
  else
    run_check "cargo check" "$c" cargo check --all-targets -q
  fi
  is_strict && run_check "cargo test" "$c" cargo test -q
done

finish_stop rust
