#!/usr/bin/env bash
# TEMPLATE PostToolUse: fast, single-file work only (format + quick lint).
# Exit 2 with a message on stderr to send errors back to Claude.
source "$(dirname "$0")/common.sh"

file="$(jget '.tool_input.file_path')"
case "$file" in *.EXT) ;; *) exit 0 ;; esac   # TODO: e.g. *.py|*.pyi or *.java|*.kt
[ -f "$file" ] || exit 0

if run_override LANG-edit "$file"; then
  [ -z "$REPORT" ] && exit 0
  printf '%s\n' "$REPORT" >&2; exit 2
fi

# TODO: formatter, e.g.   has ruff && ruff format "$file" >/dev/null 2>&1
# TODO: quick lint, e.g.  out="$(ruff check "$file" 2>&1)" || { echo "$out" >&2; exit 2; }
exit 0
