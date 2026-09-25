#!/usr/bin/env bash
# PostToolUse: FAST checks only. Format the edited file, lint it, and feed errors back.
# Project override: .harness/checks/ts-edit.sh <file>
source "$(dirname "$0")/common.sh"

file="$(jget '.tool_input.file_path')"
case "$file" in *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.mts|*.cts|*.json|*.css|*.scss) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
case "$file" in */node_modules/*|*/dist/*|*/.next/*|*/build/*) exit 0 ;; esac

root="$(project_dir)"
if run_override ts-edit "$file"; then
  [ -z "$REPORT" ] && exit 0
  printf '%s\n' "$REPORT" >&2; exit 2
fi

pkg="$(find_up "$(dirname "$file")" package.json)" || pkg="$root"
nbin() {
  local d
  for d in "$pkg" "$root"; do
    [ -x "$d/node_modules/.bin/$1" ] && { printf '%s' "$d/node_modules/.bin/$1"; return 0; }
  done
  return 1
}

# Format (never fails the hook)
if b="$(nbin biome)"; then
  (cd "$pkg" && "$b" format --write "$file") >/dev/null 2>&1 || true
elif b="$(nbin prettier)"; then
  (cd "$pkg" && "$b" --write "$file") >/dev/null 2>&1 || true
fi

# Lint code files; errors go back to Claude immediately
case "$file" in *.json|*.css|*.scss) exit 0 ;; esac
out=""
if b="$(nbin biome)"; then
  out="$(cd "$pkg" && "$b" lint "$file" 2>&1)" || { printf 'Lint errors in %s:\n%s\n' "$file" "$(printf '%s' "$out" | tail -n 40)" >&2; exit 2; }
elif b="$(nbin eslint)"; then
  out="$(cd "$pkg" && "$b" "$file" 2>&1)" || { printf 'Lint errors in %s:\n%s\n' "$file" "$(printf '%s' "$out" | tail -n 40)" >&2; exit 2; }
fi
exit 0
