#!/usr/bin/env bash
# SessionStart: stdout becomes context for the session. Orient Claude fast:
# mode, detected stacks, git state, current task, last handoff, recent learnings.
source "$(dirname "$0")/common.sh"

root="$(project_dir)"
mode="$(harness_mode)"
H="$root/.harness"

echo "## Harness context"
echo "- Mode: **${mode}** (change with HARNESS_MODE env var or .harness/mode). interactive = light checks; parallel/auto = strict stop checks, progress log."
echo "- Harness scripts dir: ${CLAUDE_PLUGIN_ROOT:-unknown}/scripts (worktree.sh, rid-check.sh)"

# Stack detection (shallow, skips heavy dirs)
stacks=""
found() { find "$root" -maxdepth 3 \( -name node_modules -o -name target -o -name .git -o -name vendor -o -name dist -o -name build \) -prune -o -name "$1" -print -quit 2>/dev/null; }
pj="$(found package.json)"
if [ -n "$pj" ]; then
  s="ts"
  grep -q '"next"' "$pj" 2>/dev/null && s="$s/next"
  grep -q '"expo"' "$pj" 2>/dev/null && s="$s/expo"
  grep -q '"react"' "$pj" 2>/dev/null && s="$s/react"
  stacks="$stacks $s"
fi
[ -n "$(found go.mod)" ] && stacks="$stacks go"
[ -n "$(found Cargo.toml)" ] && stacks="$stacks rust"
[ -n "$(found pyproject.toml)" ] && stacks="$stacks python"
echo "- Detected stacks:${stacks:- none}"
if ls "$root"/architecture/*.c4 >/dev/null 2>&1; then
  echo "- Architecture model: \`architecture/\` (LikeC4). Read it before cross-service work; update it in the same change when services, stores, or dependencies change (architecture skill)."
fi

if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  br="$(git -C "$root" branch --show-current 2>/dev/null)"
  dirty="$(git -C "$root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  echo "- Git: branch \`${br:-detached}\`, ${dirty} uncommitted file(s)"
fi

if [ -f "$H/ports.env" ]; then
  echo "- Worktree ports (use these, not defaults): $(grep -v '^#' "$H/ports.env" | tr '\n' ' ')"
fi

# Decision records, the team's rules: the folder .harness/records-source names, or the copy that
# /records syncs into .harness/records/ when it names a URL, or else docs/adr/. Listed before the
# task and handoff so they can't be pushed past the context cap. Reads the synced copy's format,
# our Status: line, adr-tools' "## Status" heading, and MADR front matter; no status = accepted.
src=""; [ -f "$H/records-source" ] && src="$(head -n 1 "$H/records-source" | tr -d '\r')"
case "$src" in
  *://*) rdir=".harness/records" ;;
  "") rdir="docs/adr" ;;
  *) rdir="${src%/}" ;;
esac
note=""
case "$src" in *://*)
  if [ ! -f "$root/$rdir/index.md" ]; then note="not synced yet: run /records"
  elif [ -n "$(find "$root/$rdir/index.md" -mtime +7 2>/dev/null)" ]; then note="last synced more than a week ago: run /records"
  fi ;;
esac
set --
for f in "$root/$rdir"/*.md; do
  case "$(basename "$f")" in index.md|INDEX.md|README.md|readme.md|[Tt]emplate*) continue ;; esac
  [ -f "$f" ] && set -- "$@" "$f"
done
[ -n "$note" ] && note="The team keeps its decision records at $src; $note."
if [ $# -eq 0 ] && [ -n "$note" ]; then
  printf '\n## Decision records\n- %s\n' "$note"
elif [ $# -gt 0 ]; then
  LC_ALL=C awk -v max=40 -v b=3000 -v lmax=160 -v dir="$rdir" -v note="$note" '
    function cut(s, m) { if (length(s) <= m) return s; s = substr(s, 1, m - 3); sub(/[\300-\377][\200-\277]*$/, "", s); return s "..." }
    function done_file(  s) {
      if (f == "" || (st != "" && st != "accepted" && st != "proposed")) return
      if (title == "") { title = f; sub(/\.md$/, "", title); gsub(/-/, " ", title) }
      s = "- " title; if (st == "proposed") { s = s " (proposed)"; kp++ } else ka++
      if (tg != "") s = s " [" tg "]"
      if (ap != "") s = s " (applies to: " ap ")"
      line[++k] = cut(s, lmax)
    }
    FNR == 1 { done_file(); f = FILENAME; sub(/.*\//, "", f); title = st = ap = tg = ""; next_st = 0 }
    { sub(/\r$/, ""); l = tolower($0) }
    next_st && $0 ~ /[^ \t]/ { st = l; sub(/^[^a-z]*/, "", st); sub(/[^a-z].*/, "", st); next_st = 0; next }
    title == "" && /^# / { title = $0; sub(/^#[ \t]*/, "", title) }
    st == "" && l ~ /^#+[ \t]*status[ \t]*$/ { next_st = 1; next }
    st == "" && l ~ /^[-*_ \t]*status[*_]*:/ { st = l; sub(/^[-*_ \t]*status[*_]*:/, "", st); sub(/^[^a-z]*/, "", st); sub(/[^a-z].*/, "", st) }
    tg == "" && l ~ /^tags:/ { tg = $0; sub(/^[Tt]ags:[ \t]*/, "", tg) }
    ap == "" && l ~ /^[-*_ \t]*applies to[*_]*:/ { ap = $0; sub(/^[-*_ \t]*[Aa]pplies to[*_]*:[*_]*[ \t]*/, "", ap) }
    END {
      done_file(); if (!k && note == "") exit
      print ""; print "## Decision records (" dir "/: " ka + 0 " accepted, " kp + 0 " proposed)"
      if (note != "") print "- " note
      if (!k) exit
      print "The team'"'"'s rules. Follow the accepted ones in what you write, and the proposed ones unless told otherwise; read a record in full before changing code it covers. The reviewer checks every change against them. Never edit them: a change of direction is a new record the team writes."
      for (i = 1; i <= k && i <= max && used + length(line[i]) + 1 <= b; i++) { print line[i]; used += length(line[i]) + 1 }
      if (i <= k) print "- and " (k - i + 1) " more in " dir "/"
    }' "$@"
fi

if [ -f "$H/current-task" ]; then
  t="$(head -n1 "$H/current-task")"
  if [ -f "$root/$t" ]; then
    echo
    echo "## Current task: $t"
    head -n 50 "$root/$t"
  fi
fi

# Most recent handoff (manual beats auto if newer)
latest=""
for f in "$H/handoff.md" "$H/handoff-auto.md"; do
  [ -f "$f" ] || continue
  if [ -z "$latest" ] || [ "$f" -nt "$latest" ]; then latest="$f"; fi
done
if [ -n "$latest" ]; then
  echo
  echo "## Last handoff ($(basename "$latest"))"
  head -n 60 "$latest"
fi

if [ -f "$H/learnings.md" ]; then
  echo
  echo "## Project learnings (most recent)"
  tail -n 25 "$H/learnings.md"
fi
G="${HOME}/.claude/harness/learnings.md"
if [ -f "$G" ]; then
  echo
  echo "## Global learnings (most recent)"
  tail -n 15 "$G"
fi
exit 0
