#!/usr/bin/env bash
# rid-check.sh <task-file> [base-ref]
# For a task with a `Requirements: R-2, R-5` line, check that each requirement ID is cited by at
# least one test file this task changed (committed since base-ref, staged, unstaged, or untracked).
# Scoping to the task's own changes keeps an old test for another spec's R-2 from counting.
# Base ref defaults to the merge-base with origin/main (or main).
# Prints one line per ID. Exit 0 = every ID is cited, 1 = some aren't, 2 = usage or setup problem.
set -uo pipefail

task="${1:-}"
[ -f "$task" ] || { echo "usage: rid-check.sh <task-file> [base-ref]" >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "rid-check: not in a git repository" >&2; exit 2; }

ids="$(grep -m1 -E '^Requirements:' "$task" | sed 's/^Requirements://' | grep -oE 'R-[0-9]+' | sort -u -t- -k2,2n)"
if [ -z "$ids" ]; then
  echo "rid-check: $task has no Requirements: line; nothing to check"
  exit 0
fi

base="${2:-}"
if [ -z "$base" ]; then
  base="$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo HEAD)"
fi

# Changed files, then keep the ones that look like tests in any of the harness's stacks.
changed="$( {
  git diff --name-only "$base" 2>/dev/null
  git diff --name-only --cached 2>/dev/null
  git ls-files --others --exclude-standard 2>/dev/null
} | sort -u)"
tests=""
while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  case "$f" in
    *_test.go|*.test.ts|*.test.tsx|*.test.js|*.test.jsx|*.test.mjs|*.spec.ts|*.spec.tsx|*.spec.js|\
    test_*.py|*/test_*.py|*_test.py|*/tests/*|tests/*|*/__tests__/*|__tests__/*|*/e2e/*|e2e/*)
      tests="$tests$f
" ;;
  esac
done <<EOF
$changed
EOF

if [ -z "$tests" ]; then
  echo "rid-check: no changed test files since $(git rev-parse --short "$base" 2>/dev/null || echo "$base")"
  for id in $ids; do echo "  $id: MISSING (no test changed)"; done
  exit 1
fi

missing=0
for id in $ids; do
  hit=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # The ID as a whole token: R-2 matches "R-2" and "(R-2)" but not "R-21" or "PR-2".
    line="$(grep -nE "(^|[^A-Za-z0-9-])${id}([^0-9]|$)" "$f" 2>/dev/null | head -n1 | cut -d: -f1)"
    if [ -n "$line" ]; then hit="$f:$line"; break; fi
  done <<EOF
$tests
EOF
  if [ -n "$hit" ]; then echo "  $id: $hit"; else echo "  $id: MISSING"; missing=1; fi
done
exit "$missing"
