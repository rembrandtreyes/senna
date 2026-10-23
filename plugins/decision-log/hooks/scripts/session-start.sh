#!/usr/bin/env bash
# SessionStart (startup, resume, clear, compact): stdout becomes context. Loads this branch's
# decision log, .harness/decisions/<branch>.md (each / in the branch name as __), and says how
# to add to it. After a compaction it also asks for any decision the summary has and the log
# doesn't: a PreCompact hook can't add to the summary, so this is where nothing gets lost.
# Moves the logs of branches that no longer exist (merged and deleted) to archive/.
# Never blocks.
source "$(dirname "$0")/common.sh"
export LC_ALL=C  # byte counts below

root="$(project_dir)"
git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || exit 0
D="$root/.harness/decisions"
br="$(git -C "$root" symbolic-ref -q --short HEAD 2>/dev/null)"  # set on an unborn branch too
logname() { printf '%s.md' "$(printf '%s' "$1" | sed 's|/|__|g')"; }
cur=""; [ -n "$br" ] && cur="$(logname "$br")"

# Archive only a log whose first line names the branch its file is named for, and never the
# current branch's, so an unborn branch or a hand-edited header can't move a live log.
archived=""
for f in "$D"/*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  [ "$name" = "$cur" ] && continue
  b="$(sed -n '1s/^# Decisions:[[:space:]]*//p' "$f" | tr -d '\r' | sed 's/[[:space:]]*$//')"
  [ -n "$b" ] && [ "$(logname "$b")" = "$name" ] || continue
  git -C "$root" show-ref --verify --quiet "refs/heads/$b" && continue
  dest="$D/archive/${name%.md}-$(date +%Y%m%d-%H%M%S).md"
  mkdir -p "$D/archive" 2>/dev/null && mv "$f" "$dest" 2>/dev/null && archived="$archived \`$b\`"
done

echo "## Decision log (decision-log plugin)"
[ -n "$archived" ] && echo "- Branch gone, so its log moved to .harness/decisions/archive/:$archived"
if [ -z "$br" ]; then
  echo "- HEAD is detached, so there's no branch log. Record decisions in the task's Log instead."
  exit 0
fi
log=".harness/decisions/$cur"
if [ -f "$root/$log" ]; then
  echo "- \`$log\`: $(grep -c '^## ' "$root/$log") decision(s) on \`$br\`, below. Don't reopen one without saying why; a reversal is a new entry."
else
  echo "- No decisions logged on \`$br\` yet (\`$log\`)."
fi
cat <<EOF
- When you or the user settle a choice between real alternatives (design, behaviour, an
  interface, data, a dependency, scope), append it to \`$log\` before the turn ends (create it
  with the line \`# Decisions: $br\` first), and say "Logged: <title>" in your reply:
  \`## YYYY-MM-DD: <what was chosen>\`, then \`- Over: <alternatives>\`, \`- Why: <reason>\`,
  \`- Files: <paths>\`. The reason is the one given; never invent one. /decide does the same.
  A decision written this turn to an ADR, a spec, PRD or interview file, or the task's Log
  counts as recorded.
EOF
if [ "$(jget '.source')" = compact ]; then
  echo "- Context was just compacted. If the summary records a decision this log doesn't have, add it now."
fi
[ -f "$root/$log" ] || exit 0

# The entries come last, within a byte budget, so the 10K context cap never cuts the
# instructions above. A long log shows its newest titles only.
budget=6000; max=60
body="$(sed 1d "$root/$log" | tr -d '\r')"
echo
if [ "$(printf '%s\n' "$body" | wc -l | tr -d ' ')" -gt "$max" ] || [ "${#body}" -gt "$budget" ]; then
  n="$(printf '%s\n' "$body" | grep -c '^## ')"
  if [ "$n" -gt "$max" ]; then echo "Newest $max of $n titles (read the file for the reasons):"
  else echo "Titles (read the file for the reasons):"; fi
  body="$(printf '%s\n' "$body" | grep '^## ' | tail -n "$max" | sed 's/^## /- /')"
else
  body="$(printf '%s\n' "$body" | sed 's/^## /### /')"
fi
printf '%s\n' "$body" | awk -v b="$budget" -v f="$log" '
  { t += length($0) + 1; if (t > b) { print "... (cut here; the rest is in " f ")"; exit } print }'
exit 0
