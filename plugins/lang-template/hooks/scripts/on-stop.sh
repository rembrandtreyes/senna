#!/usr/bin/env bash
# TEMPLATE Stop: slow checks, only when this language's files changed.
source "$(dirname "$0")/common.sh"

changed="$(changed_files EXT)"          # TODO: extensions, e.g. py pyi
[ -n "$changed" ] || { stop_passed LANG; exit 0; }

if run_override LANG-stop; then finish_stop LANG; fi

root="$(project_dir)"
# TODO: always-on checks (typecheck / compile), e.g.
# run_check "mypy" "$root" mypy .
if is_strict; then
  : # TODO: tests, e.g. run_check "pytest" "$root" pytest -q
fi

finish_stop LANG
