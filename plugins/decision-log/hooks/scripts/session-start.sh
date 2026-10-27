#!/usr/bin/env bash
# SessionStart (startup, resume, clear, compact): stdout becomes context. Loads this branch's
# decisions, one file each in .harness/decisions/<branch>/ (each / in the branch name as __),
# named NNN-<slug>.md. The index is built here from the files, so no hand-kept index can
# drift; then come the newest decisions in full, and how to add one. After a compaction it also
# asks for any decision the summary has and the folder doesn't: a PreCompact hook can't add to
# the summary, so this is where nothing gets lost. Moves the folders of branches that no longer
# exist (merged and deleted) to archive/. Never blocks.
source "$(dirname "$0")/common.sh"
export LC_ALL=C  # byte counts below

root="$(project_dir)"
git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || exit 0
D="$(harness_dir)/decisions"
# Set on an unborn branch too. Not --short: with a tag of the same name, that gives heads/<branch>.
br="$(git -C "$root" symbolic-ref -q HEAD 2>/dev/null | sed 's|^refs/heads/||')"
folder() { printf '%s' "$1" | sed 's|/|__|g'; }
cur=""; [ -n "$br" ] && cur="$(folder "$br")"
has_decisions() { for f in "$1"/[0-9]*.md; do [ -f "$f" ] && return 0; done; return 1; }

# Archive a folder of decisions that no local branch maps to (archive/ holds only folders, so
# it never qualifies). The current branch's is kept even before its first commit, when it isn't
# under refs/heads yet. A case match, not grep -q: under pipefail, grep -q quitting early on a
# long branch list fails the pipe, which would archive a live folder.
nl='
'
branches="$nl$(git -C "$root" for-each-ref --format='%(refname)' refs/heads/ 2>/dev/null | sed 's|^refs/heads/||; s|/|__|g')$nl"
archived=""; na=0
for d in "$D"/*/; do
  d="${d%/}"; name="$(basename "$d")"
  [ -d "$d" ] && [ "$name" != "$cur" ] || continue
  case "$branches" in *"$nl$name$nl"*) continue ;; esac
  has_decisions "$d" || continue
  mkdir -p "$D/archive" 2>/dev/null && mv "$d" "$D/archive/$name-$(date +%Y%m%d-%H%M%S)" 2>/dev/null &&
    { na=$((na + 1)); [ "$na" -le 5 ] && archived="$archived \`$name\`"; }
done
[ "$na" -gt 5 ] && archived="$archived and $((na - 5)) more"

echo "## Decision log (decision-log plugin)"
[ -n "$archived" ] && echo "- Branch gone, so its decisions moved to .harness/decisions/archive/:$archived"
if [ -z "$br" ]; then
  echo "- HEAD is detached, so there's no branch log. Record decisions in the task's Log instead."
  exit 0
fi
dir=".harness/decisions/$cur"
files=""
[ -d "$root/$dir" ] && files="$(cd "$root/$dir" && for f in [0-9]*.md; do [ -f "$f" ] && printf '%s\n' "$f"; done | sort -n)"
n="$(printf '%s' "$files" | grep -c .)"
if [ "$n" -gt 0 ]; then
  echo "- \`$dir/\`: $n decision(s) on \`$br\`, below. Don't reopen one without saying why."
else
  echo "- No decisions logged on \`$br\` yet (\`$dir/\`)."
fi
cat <<EOF
- When you or the user settle a choice between real alternatives (design, behaviour, an
  interface, data, a dependency, scope), write it before the turn ends to a new file,
  \`$dir/NNN-<slug>.md\` (NNN one past the highest number there, 001 for the first; the slug
  a few words of the title, lowercase), and say "Logged: <title>" in your reply. The file is
  \`# <what was chosen>\`, then \`- Date: YYYY-MM-DD\`, \`- Over: <alternatives>\`,
  \`- Why: <reason>\`, \`- Files: <paths>\`. The reason is the one given; never invent one.
  Never edit an old decision: a reversal is a new one with \`- Replaces: <its number>\`.
  /decide does the same. A decision written this turn to an ADR, a spec, PRD or interview
  file, or the task's Log counts as recorded.
EOF
if [ "$(jget '.source')" = compact ]; then
  echo "- Context was just compacted. If the summary records a decision the folder doesn't have, add it now."
fi
[ "$n" -gt 0 ] || exit 0

# The index and the newest decisions in full come last, within a byte budget, so the 10K
# context cap never cuts the instructions above. The index is filled from the newest end, so the
# highest number (the next one's base) always shows.
echo
printf '%s\n' "$files" | (cd "$root/$dir" && awk -v b=6000 -v ib=4000 -v max=60 -v lmax=160 '
  function cut(s, m) { if (length(s) <= m) return s; s = substr(s, 1, m - 3); sub(/[\300-\377][\200-\277]*$/, "", s); return s "..." }  # never half a UTF-8 character
  function out(s) { if (used + length(s) + 1 > b) return 0; used += length(s) + 1; print s; return 1 }
  { f = $0; n = f; sub(/[^0-9].*/, "", n); N++; num[N] = n; key[N] = n + 0; first = 1
    while ((getline line < f) > 0) {
      sub(/\r$/, "", line)
      if (first) {
        first = 0
        if (line ~ /^#/) { sub(/^#+[ \t]*/, "", line); sub("^0*" key[N] "[:.][ \t]*", "", line); title[N] = line; continue }
      }
      if (!seen[N] && line ~ /^- Replaces:/) {  # its number(s); "none" or prose is no reversal
        seen[N] = 1; r = line; sub(/^- Replaces:[ \t]*/, "", r)
        rep[N] = match(r, /^#?[0-9]+([ \t]*,[ \t]*#?[0-9]+)*/) ? substr(r, 1, RLENGTH) : ""
      }
      sub(/^#+/, "####", line)  # a heading inside a decision stays under its title
      if (length(body[N]) <= b) body[N] = body[N] line "\n"  # past b it can never be shown
    }
    close(f)
    if (title[N] == "") { t = f; sub(/\.md$/, "", t); sub(/^[0-9]*-*/, "", t); gsub(/-/, " ", t); title[N] = t }
  }
  END {
    for (i = 1; i <= N; i++) { r = rep[i]; while (match(r, /[0-9]+/)) { by[substr(r, RSTART, RLENGTH) + 0] = num[i]; r = substr(r, RSTART + RLENGTH) } }
    lo = N + 1; iu = 0
    for (i = N; i >= 1 && N - i < max; i--) {
      s = "- " num[i] " " title[i]
      if (key[i] in by) s = s " (replaced by " by[key[i]] ")"
      if (rep[i] != "") s = s " (replaces " rep[i] ")"
      s = cut(s, lmax)
      if (iu + length(s) + 1 > ib) break
      iu += length(s) + 1; idx[i] = s; lo = i
    }
    out(lo > 1 ? "Newest " (N - lo + 1) " of " N " decisions (the rest are in the folder):" : "Decisions (each file has the reasons):")
    for (i = lo; i <= N; i++) out(idx[i])
    # Then the listed ones still in force, newest first, in full: each that fits.
    for (i = N; i >= lo; i--) {
      if (key[i] in by) continue
      s = "### " num[i] " " title[i] "\n" body[i]; sub(/\n+$/, "", s)
      s = (shown ? "\n" : "\nIn full, newest first (any too long to fit are left out):\n") s
      if (out(s)) shown = 1
    }
  }')
exit 0
