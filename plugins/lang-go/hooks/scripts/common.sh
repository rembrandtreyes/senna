#!/usr/bin/env bash
# Shared helpers for harness hook scripts.
# CANONICAL COPY: shared/common.sh. Edit it there, then run scripts/sync-common.sh.
# (Installed plugins are copied into a cache and can't reference files outside
#  their own folder, so each plugin carries its own copy of this file.)

set -uo pipefail

has() { command -v "$1" >/dev/null 2>&1; }

if ! has jq; then
  echo "harness: jq not found, hook skipped (install jq to enable guardrails)" >&2
  exit 0
fi

HOOK_INPUT="$(cat)"

# jget '.tool_input.file_path'  -> value, or empty string
jget() { printf '%s' "$HOOK_INPUT" | jq -r "$1 // empty" 2>/dev/null; }

project_dir() {
  local d="${CLAUDE_PROJECT_DIR:-}"
  [ -z "$d" ] && d="$(jget '.cwd')"
  [ -z "$d" ] && d="$(pwd)"
  printf '%s' "$d"
}

# Mode: HARNESS_MODE env var > .harness/mode file > "interactive"
harness_mode() {
  if [ -n "${HARNESS_MODE:-}" ]; then printf '%s' "$HARNESS_MODE"; return; fi
  local f; f="$(project_dir)/.harness/mode"
  if [ -f "$f" ]; then tr -d '[:space:]' < "$f"; return; fi
  printf 'interactive'
}

is_strict() { case "$(harness_mode)" in auto|parallel) return 0 ;; *) return 1 ;; esac; }

# find_up <start-dir> <marker> : nearest ancestor (inclusive) containing marker,
# bounded by the project dir.
find_up() {
  local dir="$1" marker="$2" stop
  stop="$(project_dir)"
  while :; do
    if [ -e "$dir/$marker" ]; then printf '%s' "$dir"; return 0; fi
    if [ "$dir" = "$stop" ] || [ "$dir" = "/" ] || [ "$dir" = "." ]; then return 1; fi
    dir="$(dirname "$dir")"
  done
}

# changed_files ext1 ext2 ... : absolute paths of modified/untracked files with
# those extensions (every changed file when no extension is given). Stop hooks use
# this to skip languages you didn't touch.
changed_files() {
  local root top
  root="$(project_dir)"
  top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || return 0
  git -C "$root" status --porcelain --untracked-files=all 2>/dev/null \
    | sed -E 's/^.{3}//; s/.* -> //; s/^"//; s/"$//' \
    | while IFS= read -r f; do
        [ -e "$top/$f" ] || continue
        [ $# -eq 0 ] && { printf '%s\n' "$top/$f"; continue; }
        for ext in "$@"; do
          case "$f" in *."$ext") printf '%s\n' "$top/$f"; break ;; esac
        done
      done
}

# Stop-hook retry budget.
#   interactive: block at most once per turn.
#   auto/parallel: up to HARNESS_MAX_STOP_RETRIES (default 3) consecutive
#   blocks, then hand back to the human instead of looping forever.
stop_may_block() {
  local key="$1" max=1 n=0 f
  is_strict && max="${HARNESS_MAX_STOP_RETRIES:-3}"
  f="$(project_dir)/.harness/.stop-attempts-$key"
  mkdir -p "$(dirname "$f")"
  if [ "$(jget '.stop_hook_active')" = "true" ] && [ -f "$f" ]; then
    n="$(cat "$f" 2>/dev/null || echo 0)"
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
  fi
  if [ "$n" -ge "$max" ]; then rm -f "$f"; return 1; fi
  echo $((n + 1)) > "$f"
  return 0
}
stop_passed() { rm -f "$(project_dir)/.harness/.stop-attempts-$1"; }

# REPORT accumulates failures from run_check.
REPORT=""

# run_check <label> <dir> <cmd...>
run_check() {
  local label="$1" dir="$2"; shift 2
  local out
  if ! out="$(cd "$dir" && "$@" 2>&1)"; then
    REPORT="${REPORT}
### ${label} (in ${dir})
$(printf '%s\n' "$out" | tail -n 40)"
  fi
}

# finish_stop <key> : exit 0 if REPORT is empty; otherwise block (exit 2) so
# Claude keeps working, or, once the retry budget is spent, report to the human.
finish_stop() {
  local key="$1"
  if [ -z "$REPORT" ]; then stop_passed "$key"; exit 0; fi
  if stop_may_block "$key"; then
    printf 'Harness verification failed (%s). Fix these before finishing:%s\n' "$key" "$REPORT" >&2
    exit 2
  fi
  printf 'Harness: %s checks still failing after retries; handing back to you.%s\n' "$key" "$REPORT" \
    | head -n 60 >&2
  exit 1
}

# test_nudge <key> <sources> <tests> <project-has-tests> : when source files changed and no
# test file did, add a note to REPORT asking for a test or a one-line reason there's none.
# Asks once per distinct set of changed source files, so a stated reason isn't re-asked.
# Skipped when the project has no tests of this kind yet, or with HARNESS_TEST_NUDGE=off.
test_nudge() {
  local key="$1" sources="$2" tests="$3" has_tests="$4" f sig list root
  [ "${HARNESS_TEST_NUDGE:-on}" = off ] && return 0
  [ -n "$sources" ] && [ -z "$tests" ] && [ -n "$has_tests" ] || return 0
  f="$(project_dir)/.harness/.test-nudge-$key"
  sig="$(printf '%s\n' "$sources" | sort | git hash-object --stdin 2>/dev/null)"
  [ -f "$f" ] && [ "$(cat "$f" 2>/dev/null)" = "$sig" ] && return 0
  mkdir -p "$(dirname "$f")" 2>/dev/null && echo "$sig" > "$f" 2>/dev/null
  root="$(git -C "$(project_dir)" rev-parse --show-toplevel 2>/dev/null || project_dir)"
  list="$(printf '%s\n' "$sources" | sed "s|^$root/||" | head -n 10 | sed 's/^/- /')"
  REPORT="${REPORT}
### no test changed (${key})
Source files changed but no test did:
${list}
Add or update a test at the cheapest layer that would catch a regression (see the testing
skill). If this change needs none (a refactor existing tests already cover, config, copy,
types only), say why in one line in your final message instead. Asked once per set of files."
}

# run_override <name> [args...] : if the project ships .harness/checks/<name>.sh,
# run it instead of the plugin defaults (HARNESS_MODE is set to the resolved mode). This is how you adapt the harness to
# any build system (Nx, Bazel, Gradle, make...) without forking the plugin.
# Returns 1 if there is no override.
run_override() {
  local name="$1"; shift
  local script
  script="$(project_dir)/.harness/checks/${name}.sh"
  [ -x "$script" ] || return 1
  run_check "project override ${name}" "$(project_dir)" env HARNESS_MODE="$(harness_mode)" "$script" "$@"
  return 0
}

# ---- Review verdicts: recorded by core's SubagentStop hook, checked by the Stop gates ----------
# A critic or reviewer ends its output with `REVIEWED: <path>` and `VERDICT: <word>`. The verdict
# is stored with the hash of what it reviewed, so a later edit makes it stale.

# doc_hash <file> : hash of a doc without the Status line in its header, so moving it from draft
# to in review to approved isn't a content change.
doc_hash() { awk 'NR<=6 && /Status:/ {next} {print}' "$1" 2>/dev/null | git hash-object --stdin 2>/dev/null; }

# spec_bundle_hash <spec-dir> : spec.md (without its Status line) plus the proposal model
spec_bundle_hash() {
  { awk 'NR<=6 && /Status:/ {next} {print}' "$1/spec.md" 2>/dev/null
    cat "$1"/model/*.c4 2>/dev/null; } | git hash-object --stdin 2>/dev/null
}

# work_hash : the change under review: HEAD, the uncommitted diff, and untracked files' contents,
# leaving out .harness/ (the hooks' own state would otherwise change it on every run)
work_hash() {
  local r; r="$(project_dir)"
  { git -C "$r" rev-parse HEAD
    git -C "$r" diff HEAD -- . ':(exclude).harness'
    git -C "$r" ls-files --others --exclude-standard -- . ':(exclude).harness' \
      | while IFS= read -r f; do printf '%s %s\n' "$f" "$(git hash-object "$r/$f" 2>/dev/null)"; done
  } 2>/dev/null | git hash-object --stdin 2>/dev/null
}

# subject_hash <repo-relative path> : the hash a verdict on that path is checked against
subject_hash() {
  local r; r="$(project_dir)"
  case "$1" in
    */prd.md) doc_hash "$r/$1" ;;
    */spec.md) spec_bundle_hash "$r/$(dirname "$1")" ;;
    *) work_hash ;;
  esac
}

# verdict_file <repo-relative path> : where the latest verdict on it is kept
verdict_file() { printf '%s/.harness/verdicts/%s' "$(project_dir)" "$(printf '%s' "$1" | sed 's|/|__|g')"; }

# gate_once <key> <hash> : succeed (ask) only the first time a gate fires for this hash, so a
# user who chose to skip a review isn't asked again until the subject changes.
gate_once() {
  local f; f="$(project_dir)/.harness/.gate-$1"
  [ -f "$f" ] && [ "$(cat "$f" 2>/dev/null)" = "$2" ] && return 1
  mkdir -p "$(dirname "$f")" 2>/dev/null && echo "$2" > "$f" 2>/dev/null
  return 0
}
