#!/usr/bin/env bash
# PostToolUse: rustfmt the edited file only (cargo check is too slow per edit and
# runs at Stop instead). Syntax errors come straight back to Claude.
# Override: .harness/checks/rust-edit.sh <file>
source "$(dirname "$0")/common.sh"

file="$(jget '.tool_input.file_path')"
case "$file" in *.rs) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
case "$file" in */target/*) exit 0 ;; esac

if run_override rust-edit "$file"; then
  [ -z "$REPORT" ] && exit 0
  printf '%s\n' "$REPORT" >&2; exit 2
fi
has rustfmt || exit 0

crate="$(find_up "$(dirname "$file")" Cargo.toml)" || crate="$(project_dir)"
edition="$(grep -E '^[[:space:]]*edition[[:space:]]*=[[:space:]]*"' "$crate/Cargo.toml" 2>/dev/null | head -n1 | sed -E 's/.*"([0-9]+)".*/\1/')"
out="$(cd "$crate" && rustfmt --edition "${edition:-2021}" "$file" 2>&1)" \
  || { printf 'rustfmt failed on %s (likely a syntax error):\n%s\n' "$file" "$(printf '%s' "$out" | tail -n 30)" >&2; exit 2; }
exit 0
