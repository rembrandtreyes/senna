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
# those extensions. Stop hooks use this to skip languages you didn't touch.
changed_files() {
  local root top
  root="$(project_dir)"
  top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || return 0
  git -C "$root" status --porcelain --untracked-files=all 2>/dev/null \
    | sed -E 's/^.{3}//; s/.* -> //; s/^"//; s/"$//' \
    | while IFS= read -r f; do
        [ -e "$top/$f" ] || continue
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
