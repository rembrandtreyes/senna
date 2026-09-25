#!/usr/bin/env bash
# Notification: Claude needs permission or has been waiting on you.
# Desktop notification locally; set HARNESS_NTFY_TOPIC (ntfy.sh) to get it on your phone.
source "$(dirname "$0")/common.sh"

msg="$(jget '.message')"
[ -n "$msg" ] || msg="Claude Code needs your attention"
title="Claude · $(basename "$(project_dir)")"

if has osascript; then
  osascript -e "display notification \"${msg//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1 || true
elif has notify-send; then
  notify-send "$title" "$msg" >/dev/null 2>&1 || true
fi
if [ -n "${HARNESS_NTFY_TOPIC:-}" ] && has curl; then
  curl -s -m 5 -H "Title: $title" -d "$msg" "${HARNESS_NTFY_URL:-https://ntfy.sh}/${HARNESS_NTFY_TOPIC}" >/dev/null 2>&1 || true
fi
exit 0
