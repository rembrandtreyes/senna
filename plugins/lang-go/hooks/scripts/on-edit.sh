#!/usr/bin/env bash
# PostToolUse: format the edited Go file (goimports if available, else gofmt).
# A syntax error comes straight back to Claude. Override: .harness/checks/go-edit.sh <file>
source "$(dirname "$0")/common.sh"

file="$(jget '.tool_input.file_path')"
case "$file" in *.go) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
case "$file" in */vendor/*) exit 0 ;; esac

if run_override go-edit "$file"; then
  [ -z "$REPORT" ] && exit 0
  printf '%s\n' "$REPORT" >&2; exit 2
fi

if has goimports; then
  out="$(goimports -w "$file" 2>&1)" || { printf 'Go syntax/format error in %s:\n%s\n' "$file" "$out" >&2; exit 2; }
elif has gofmt; then
  out="$(gofmt -w "$file" 2>&1)" || { printf 'Go syntax/format error in %s:\n%s\n' "$file" "$out" >&2; exit 2; }
fi
exit 0
