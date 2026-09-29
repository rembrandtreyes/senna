#!/usr/bin/env bash
# Stop: a PRD or spec marked "in review" or "approved" must have a PASS from its critic for its
# current content (the Status line doesn't count; for a spec, the model does). Catches a skipped
# critic and a revision that wasn't re-checked. Drafts are left alone. Asks once per version, so
# a user who chose to skip isn't re-asked until the doc changes. HARNESS_STEP_GATE=off disables it.
source "$(dirname "$0")/common.sh"

[ "${HARNESS_STEP_GATE:-on}" = off ] && exit 0
root="$(project_dir)"
[ -n "$(ls "$root"/specs/*/prd.md "$root"/specs/*/spec.md 2>/dev/null)" ] || exit 0

asks=""
for f in "$root"/specs/*/prd.md "$root"/specs/*/spec.md; do
  [ -f "$f" ] || continue
  rel="${f#"$root"/}"; doc="$(basename "$f" .md)"
  status="$(grep -m1 -E '(^|[[:space:]])Status:' "$f" | sed -E 's/.*Status:[[:space:]]*//; s/[[:space:]]*·.*//; s/[[:space:]]+$//')"
  case "$status" in "in review"*|approved*) ;; *) continue ;; esac
  now="$(subject_hash "$rel")"
  v="$(verdict_file "$rel")"
  if [ -f "$v" ]; then
    read -r verdict hash _ < "$v"
    [ "$verdict" = PASS ] && [ "$hash" = "$now" ] && continue
  fi
  gate_once "step-$(printf '%s' "$rel" | sed 's|/|__|g')" "$now" || continue
  asks="$asks
- $rel is \"$status\" but ${doc}-critic hasn't passed this version: run the ${doc}-critic agent on it"
done

[ -n "$asks" ] || exit 0
cat >&2 <<EOF
Harness step gate:$asks
Fix what it reports, re-run it until PASS, then finish. If the user has chosen to skip the
critic, say so and finish; this is asked once per version of the doc.
EOF
exit 2
