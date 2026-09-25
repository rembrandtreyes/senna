#!/usr/bin/env bash
# PostToolUse(*): in parallel/auto mode, append a one-line trail of every action to
# .harness/progress.log so you can see what an unattended run did.
source "$(dirname "$0")/common.sh"
is_strict || exit 0

tool="$(jget '.tool_name')"
case "$tool" in
  Bash) what="$(jget '.tool_input.command' | tr '\n' ' ' | cut -c1-140)" ;;
  Edit|Write|MultiEdit|Read) what="$(jget '.tool_input.file_path')" ;;
  Task|Agent) what="$(jget '.tool_input.description')" ;;
  *) what="" ;;
esac
mkdir -p "$(project_dir)/.harness"
printf '%s  %-10s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tool" "$what" >> "$(project_dir)/.harness/progress.log"
exit 0
