#!/usr/bin/env bash
# Stop: only if .rs files changed.
#   interactive: cargo clippy (or cargo check); stricter lints via HARNESS_CLIPPY_FLAGS="-D warnings"
#   parallel/auto: + cargo test
# Override: .harness/checks/rust-stop.sh
source "$(dirname "$0")/common.sh"
has cargo || exit 0

changed="$(changed_files rs)"
[ -n "$changed" ] || { stop_passed rust; exit 0; }

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
