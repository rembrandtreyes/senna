#!/usr/bin/env bash
# SessionStart: one line per spec in progress (not yet implemented): its status, whether the deck
# is stale or unpublished, open feedback, and sign-off, so the next step is obvious.
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/specs-lib.sh"

root="$(project_dir)"
ls "$root"/specs/*/spec.md >/dev/null 2>&1 || exit 0
cd "$root" || exit 0

lines=""
for spec in specs/*/spec.md; do
  d="$(dirname "$spec")"; slug="$(basename "$d")"
  status="$(spec_header "$d" Status)"; ver="$(spec_header "$d" Version)"
  case "$status" in implemented*) continue ;; esac
  parts="spec ${ver:-v?} ${status:-no status}"

  case "$(deck_state "$d")" in
    none) parts="$parts; no deck" ;;
    stale-spec) parts="$parts; **deck stale** (spec changed since /present)" ;;
    stale-model) parts="$parts; **deck stale** (model changed since /present)" ;;
    stale-both) parts="$parts; **deck stale** (spec and model changed since /present)" ;;
    fresh)
      pub="$d/deck/publish.json"
      if [ ! -f "$pub" ]; then parts="$parts; deck built, not published"
      elif [ "$(jfield "$pub" specHash)" != "$(jfield "$d/deck/build-info.json" specHash)" ]; then
        parts="$parts; published deck is older than the built one (republish)"
      else parts="$parts; published ($(jfield "$pub" adapter))"; fi ;;
  esac

  if [ -f "$d/feedback.md" ]; then
    read -r n c m <<EOF
$(open_feedback "$d")
EOF
    if [ "$n" -gt 0 ]; then parts="$parts; feedback: $n open ($c critical, $m major)"
    elif signed_off "$d"; then parts="$parts; signed off"
    else parts="$parts; feedback: none open, not signed off"; fi
  fi
  lines="$lines
- \`$slug\`: $parts"
done

[ -n "$lines" ] || exit 0
echo "## Specs in progress (plan plugin)$lines"
echo "Next steps: stale deck → /present; unpublished → /publish; open feedback → /feedback; signed off → /breakdown <slug>."
exit 0
