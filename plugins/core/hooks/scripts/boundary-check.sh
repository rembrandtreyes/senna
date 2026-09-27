#!/usr/bin/env bash
# Stop: warn (never block) when a change touches a project-defined boundary, such as migrations,
# queries, or a third-party API schema, and no test that exercises the real thing changed.
# Rules live in the project, in .harness/checks/boundaries.txt, one per line:
#   <boundary glob> => <globs of tests that hit the real dependency, space- or comma-separated>
#   supabase/migrations/* => tests/integration/* *.integration.test.ts
# Globs are shell case patterns relative to the repo root; `*` also matches `/`.
# Warns once per distinct set of boundary files. HARNESS_BOUNDARY_CHECK=off disables it.
source "$(dirname "$0")/common.sh"

[ "${HARNESS_BOUNDARY_CHECK:-on}" = off ] && exit 0
root="$(project_dir)"
rules="$root/.harness/checks/boundaries.txt"
[ -f "$rules" ] || exit 0
top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || exit 0
changed="$(changed_files | sed "s|^$top/||")"
[ -n "$changed" ] || exit 0

warn=""; hits_all=""
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|'#'*) continue ;; esac
  case "$line" in *'=>'*) ;; *) continue ;; esac
  lhs="$(printf '%s' "${line%%=>*}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  rhs="$(printf '%s' "${line#*=>}" | tr ',' ' ' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -n "$lhs" ] && [ -n "$rhs" ] || continue
  hits=""; verified=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    set -f  # the globs below are patterns, not files to expand
    for g in $rhs; do
      # shellcheck disable=SC2254
      case "$f" in $g) verified=1 ;; esac
    done
    set +f
    # A test sitting inside a boundary directory isn't a boundary change.
    case "$f" in *.test.*|*.spec.*|*_test.*|*/test_*|test_*|*/__tests__/*|*/tests/*) continue ;; esac
    # shellcheck disable=SC2254
    case "$f" in $lhs) hits="$hits $f" ;; esac
  done <<< "$changed"
  if [ -n "$hits" ] && [ -z "$verified" ]; then
    warn="$warn
- $lhs changed (${hits# }) but nothing matching $rhs did"
    hits_all="$hits_all$hits"
  fi
done < "$rules"

[ -n "$warn" ] || exit 0
mark="$root/.harness/.boundary-warned"
sig="$(printf '%s\n' "$hits_all" | git hash-object --stdin 2>/dev/null)"
[ -f "$mark" ] && [ "$(cat "$mark" 2>/dev/null)" = "$sig" ] && exit 0
msg="Harness boundary check (warning): a boundary changed with only mocked or no tests.$warn
A mock can agree with the code and disagree with reality; add a test against the real dependency (rules: .harness/checks/boundaries.txt)."
jq -n --arg m "$msg" '{systemMessage: $m}' || exit 0
mkdir -p "$(dirname "$mark")" 2>/dev/null && echo "$sig" > "$mark" 2>/dev/null
exit 0
