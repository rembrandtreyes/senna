#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit): when an edit makes a spec's built deck stale (spec.md or a
# model/*.c4 file changed since /present), tell Claude once per change so it can mention it.
# Never blocks; stays quiet when there's no deck.
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/specs-lib.sh"

f="$(jget '.tool_input.file_path')"
case "$f" in
  */specs/*/spec.md) d="$(dirname "$f")" ;;
  */specs/*/model/*.c4) d="$(dirname "$(dirname "$f")")" ;;
  *) exit 0 ;;
esac
[ -f "$d/deck/build-info.json" ] || exit 0
cd "$d" 2>/dev/null || exit 0

state="$(deck_state "$d")"
case "$state" in stale-*) ;; *) exit 0 ;; esac

# One notice per build: remember which build we already reported stale, so a run of edits
# produces one notice, and the next build that goes stale produces a new one.
slug="$(basename "$d")"
mark="$(project_dir)/.harness/.deck-stale-$slug"
build="$(jfield "$d/deck/build-info.json" builtAt) $(jfield "$d/deck/build-info.json" specHash)"
[ -f "$mark" ] && [ "$(cat "$mark" 2>/dev/null)" = "$build" ] && exit 0

# (No case statement inside $(...): bash 3.2 can't parse one there.)
what="spec.md and the model"
[ "$state" = stale-spec ] && what="spec.md"
[ "$state" = stale-model ] && what="the model"
msg="The review deck for specs/$slug is now stale: $what changed since /present built it. When this round of edits is done, tell the user and suggest /present $slug (and /publish to update reviewers)."
jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}}' || exit 0
# Record the notice only after it's out.
mkdir -p "$(dirname "$mark")" 2>/dev/null && echo "$build" > "$mark" 2>/dev/null
exit 0
