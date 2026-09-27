#!/usr/bin/env bash
# Helpers for the plan plugin's hooks: the state of a spec's deck, feedback, and sign-off.
# Source after common.sh (it provides jq and project_dir).

# spec_hash <spec-dir> : git blob hash of spec.md (what /present records as specHash)
spec_hash() { git hash-object "$1/spec.md" 2>/dev/null; }

# model_hash <spec-dir> : hash of the proposal model's .c4 files in name order, or empty if none
# (what /present records as modelHash)
model_hash() {
  ls "$1"/model/*.c4 >/dev/null 2>&1 || return 0
  cat "$1"/model/*.c4 | git hash-object --stdin 2>/dev/null
}

# jfield <file> <key> : a top-level string field of a JSON file, or empty
jfield() { jq -r --arg k "$2" '.[$k] // empty' "$1" 2>/dev/null; }

# deck_state <spec-dir> : none | fresh | stale-spec | stale-model | stale-both
deck_state() {
  local d="$1" info s m
  info="$d/deck/build-info.json"
  [ -f "$info" ] || { echo none; return; }
  s=fresh; m=fresh
  [ "$(spec_hash "$d")" = "$(jfield "$info" specHash)" ] || s=stale
  # Decks built before modelHash existed have no recorded value; don't call those stale.
  if [ -n "$(jfield "$info" modelHash)" ] && [ "$(model_hash "$d")" != "$(jfield "$info" modelHash)" ]; then m=stale; fi
  case "$s$m" in
    freshfresh) echo fresh ;;
    stalefresh) echo stale-spec ;;
    freshstale) echo stale-model ;;
    *) echo stale-both ;;
  esac
}

# spec_header <spec-dir> <field> : Status or Version from spec.md's header line
#   "Status: in review   ·   Version: v2   ·   Author: ..."
spec_header() {
  grep -m1 -E "(^|[[:space:]])$2:" "$1/spec.md" 2>/dev/null \
    | sed -E "s/.*(^|[[:space:]])$2:[[:space:]]*//; s/[[:space:]]*·.*//; s/[[:space:]]+$//"
}

# open_feedback <spec-dir> : "<open> <critical> <major>" counts of open ledger items
open_feedback() {
  local f="$1/feedback.md"
  [ -f "$f" ] || { echo "0 0 0"; return; }
  # Items table columns: ID | Ver | Source | Reviewer | Section | Kind | Sev | Summary | Status | ...
  awk -F'|' '
    $2 ~ /^ *F-[0-9]+ *$/ {
      st=$10; sev=$8; gsub(/ /, "", st); gsub(/ /, "", sev)
      if (st == "open") { n++; if (sev == "critical") c++; if (sev == "major") m++ }
    }
    END { printf "%d %d %d\n", n, c, m }' "$f"
}

# signed_off <spec-dir> : exit 0 if feedback.md's Sign-off line is filled in
signed_off() {
  local line
  line="$(grep -m1 -E '^Spec:.*Sign-off:|^Sign-off:' "$1/feedback.md" 2>/dev/null | sed -E 's/.*Sign-off:[[:space:]]*//')"
  [ -n "$line" ] && case "$line" in "<"*) return 1 ;; *) return 0 ;; esac
}
