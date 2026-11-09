#!/usr/bin/env bash
# icm-audit.sh [repo-dir]          Mechanical ICM checks of a repo's agent context. Read-only;
#                                  prints a markdown report (findings ranked blocker > should >
#                                  consider > info) for the icm skill to verify and explain.
# icm-audit.sh stamp <CONTEXT.md>  Print the inputs hash a workflow stage writes into its outputs.
#
# Loader facts it encodes (Claude Code docs, checked 2026-11, v2.1.319): root CLAUDE.md files and
# unscoped root rules load at launch, @imports load with the file that names them (max 4 hops),
# nested CLAUDE.md files and nested or path-scoped rules load on demand and are cut off past
# ~40,000 characters (200K window), a rule's `paths:` resolve from the folder that holds its
# `.claude/` folder, AGENTS.md is read only when no CLAUDE.md/CLAUDE.local.md exists at or above
# the working directory (or when a CLAUDE.md imports it), skill descriptions over 1,536 characters
# are cut off in the listing.
#
# Portable: bash 3.2 and BSD tools (no arrays under set -u, no GNU-only flags).
set -u

LAUNCH_BUDGET="${ICM_LAUNCH_BUDGET:-1200}"     # tokens; ICM paper: L0 ~800 + L1 ~300
AREA_BUDGET="${ICM_AREA_BUDGET:-8000}"         # tokens; ICM paper: 2-8k per stage, all layers
ONDEMAND_LIMIT="${ICM_ONDEMAND_CHARS:-40000}"  # chars; on-demand files are truncated past this
LINE_LIMIT=200      # docs: target under 200 lines per CLAUDE.md
SKILL_LINES=500     # docs: keep SKILL.md under 500 lines
DESC_LIMIT=1536     # docs: description + when_to_use cut off past this in the skill listing

tmp="$(mktemp -d "${TMPDIR:-/tmp}/icm-audit.XXXXXX")" || exit 1
trap 'rm -rf "$tmp"' EXIT

n_bytes() { wc -c <"$1" 2>/dev/null | tr -d ' '; }
n_chars() { wc -m <"$1" 2>/dev/null | tr -d ' '; }
n_lines() { awk 'END{print NR}' "$1" 2>/dev/null; }
tok() { echo $(( ${1:-0} / 4 )); }

# Body of a markdown file without its leading YAML frontmatter.
body_of() { awk 'NR==1&&/^---[ \t]*$/{fm=1;next} fm&&/^---[ \t]*$/{fm=0;next} !fm' "$1"; }

# Raw @import targets of a file: outside fenced code and inline code spans, `@` at a word start.
raw_imports() {
  awk '
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0; gsub(/`[^`]*`/, "", line)
      while (match(line, /(^|[ \t(])@[A-Za-z0-9._~\/-]+/)) {
        t = substr(line, RSTART, RLENGTH); sub(/^[ \t(]*@/, "", t); sub(/[.,;:)]+$/, "", t)
        if (t ~ /[.\/]/) print t
        line = substr(line, RSTART + RLENGTH)
      }
    }' "$1"
}

# Resolve an import target against the importing file's folder. Prints the path; exit 1 if missing.
resolve_import() {
  local from="$1" t="$2" p
  # shellcheck disable=SC2088  # a literal "~/" in the import text, expanded by hand
  case "$t" in
    "~/"*) p="$HOME/${t#\~/}" ;;
    /*) p="$t" ;;
    *) p="$(dirname "$from")/$t" ;;
  esac
  printf '%s\n' "$p"
  [ -f "$p" ]
}

# Bytes of a file plus everything it imports (4 hops, each file once). Appends "from<TAB>to" to
# $tmp/edges and "from<TAB>target" to $tmp/missing_imports. Uses $tmp/visited for cycles.
expand_bytes() {
  local f="$1" d="$2" total t p
  if grep -Fxq -- "$f" "$tmp/visited" 2>/dev/null; then echo 0; return; fi
  printf '%s\n' "$f" >> "$tmp/visited"
  total="$(n_bytes "$f")"; total="${total:-0}"
  if [ "$d" -lt 4 ]; then
    while IFS= read -r t <&4; do
      if p="$(resolve_import "$f" "$t")"; then
        printf '%s\t%s\n' "$f" "$p" >> "$tmp/edges"
        total=$(( total + $(expand_bytes "$p" $(( d + 1 ))) ))
      else
        printf '%s\t%s\n' "$f" "$t" >> "$tmp/missing_imports"
      fi
    done 4< <(raw_imports "$f")
  fi
  echo "$total"
}
expanded() { : > "$tmp/visited"; expand_bytes "$1" 0; }

# Brace expansion for rule patterns: "src/**/*.{ts,tsx}" -> two lines.
expand_braces() {
  local p="$1" pre rest body post
  case "$p" in *"{"*"}"*) ;; *) printf '%s\n' "$p"; return ;; esac
  pre="${p%%\{*}"; rest="${p#*\{}"; body="${rest%%\}*}"; post="${rest#*\}}"
  printf '%s\n' "$body" | tr ',' '\n' | while IFS= read -r alt; do expand_braces "$pre$alt$post"; done
}

# Files a rule pattern matches, relative to the base folder (Claude Code's rules semantics:
# no slash = any depth, leading slash = base folder only, else anchored at the base folder).
glob_files() {
  local base="$1" p="$2" spec
  case "$p" in /*) spec="${p#/}" ;; */*) spec="$p" ;; *) spec="**/$p" ;; esac
  (cd "$base" 2>/dev/null && git ls-files --cached --others --exclude-standard -- ":(glob)$spec" 2>/dev/null)
}

# Inputs hash of a stage contract: cksum of its existing Inputs, in order.
stage_inputs() {
  awk '
    /^## /{ sec = $0; next }
    sec ~ /^## Inputs/ && /^[ \t]*[-*][ \t]/ {
      if (match($0, /`[^`]+`/)) print substr($0, RSTART + 1, RLENGTH - 2)
    }' "$1"
}
stage_hash() {
  local ctx="$1" dir t p
  dir="$(dirname "$ctx")"
  stage_inputs "$ctx" | while IFS= read -r t; do
    p="$dir/${t%%#*}"; [ -f "$p" ] && cat "$p"
  done | cksum | awk '{print $1 "-" $2}'
}

if [ "${1:-}" = stamp ]; then
  [ -f "${2:-}" ] || { echo "usage: icm-audit.sh stamp <CONTEXT.md>" >&2; exit 2; }
  stage_hash "$2"; exit 0
fi

root="$(cd "${1:-.}" 2>/dev/null && pwd -P)" || { echo "icm-audit: no such folder: ${1:-.}" >&2; exit 2; }
rel() { case "$1" in "$root") echo . ;; "$root"/*) echo "${1#"$root"/}" ;; *) echo "$1" ;; esac; }
is_git=0; git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 && is_git=1

: > "$tmp/findings"; : > "$tmp/edges"; : > "$tmp/missing_imports"
# finding <severity> <id> <file> <message>
finding() {
  local r=4
  case "$1" in blocker) r=1 ;; should) r=2 ;; consider) r=3 ;; esac
  printf '%s\t[%s] %s %s: %s\n' "$r" "$1" "$2" "$3" "$4" >> "$tmp/findings"
}

# ---- Inventory ------------------------------------------------------------------------------
find "$root" \( -name node_modules -o -name .git -o -name dist -o -name build -o -name target \
  -o -name vendor -o -name .next -o -name .venv -o -name venv -o -name __pycache__ -o -name .turbo \
  -o -name .nx -o -name coverage -o -name .harness -o -name .worktrees -o -path "$root/.claude/worktrees" \) -prune \
  -o -type f \( -name CLAUDE.md -o -name CLAUDE.local.md -o -name AGENTS.md -o -name SKILL.md \
  -o -name CONTEXT.md -o -path '*/.claude/rules/*.md' -o -path '*/.cursor/rules/*' -o -name .cursorrules \
  -o -name copilot-instructions.md -o -path '*/.github/instructions/*' -o -path '*/.windsurf/rules/*' \
  -o -path '*/.clinerules/*' -o -name GEMINI.md \) -print 2>/dev/null | sort > "$tmp/all"

grep -E '/(\.claude/)?CLAUDE(\.local)?\.md$' "$tmp/all" > "$tmp/claude" || true
grep -E '/(\.claude/)?AGENTS\.md$' "$tmp/all" > "$tmp/agents" || true
grep '/\.claude/rules/' "$tmp/all" | grep '\.md$' > "$tmp/rules" || true
grep '/SKILL\.md$' "$tmp/all" > "$tmp/skills" || true
grep '/CONTEXT\.md$' "$tmp/all" > "$tmp/contexts" || true
grep -E '/\.cursor/rules/|/\.cursorrules$|copilot-instructions\.md$|/\.github/instructions/|/\.windsurf/rules/|/\.clinerules/|/GEMINI\.md$' \
  "$tmp/all" > "$tmp/other" || true

# Folder of a context file: strip the name and a trailing /.claude.
ctx_dir() { local d; d="$(dirname "$1")"; case "$d" in */.claude) d="${d%/.claude}" ;; esac; echo "$d"; }

mode=none
for f in CLAUDE.md .claude/CLAUDE.md CLAUDE.local.md; do [ -f "$root/$f" ] && mode=claude; done
if [ "$mode" = none ]; then
  for f in AGENTS.md .claude/AGENTS.md; do [ -f "$root/$f" ] && mode=agents; done
fi

# ---- Launch context (L0 + L1) ---------------------------------------------------------------
: > "$tmp/launch"   # file<TAB>bytes(expanded)
if [ "$mode" = claude ]; then
  for f in CLAUDE.md .claude/CLAUDE.md CLAUDE.local.md; do [ -f "$root/$f" ] && echo "$root/$f"; done > "$tmp/launch_files"
elif [ "$mode" = agents ]; then
  for f in AGENTS.md .claude/AGENTS.md; do [ -f "$root/$f" ] && echo "$root/$f"; done > "$tmp/launch_files"
else
  : > "$tmp/launch_files"
fi
launch_bytes=0
while IFS= read -r f <&3; do
  b="$(expanded "$f")"; launch_bytes=$(( launch_bytes + b ))
  printf '%s\t%s\n' "$(rel "$f")" "$b" >> "$tmp/launch"
  cat "$tmp/visited" >> "$tmp/launch_expanded"
done 3< "$tmp/launch_files"
[ -f "$tmp/launch_expanded" ] || : > "$tmp/launch_expanded"
sort -u "$tmp/launch_expanded" -o "$tmp/launch_expanded"

# A local file in an AGENTS.md-only repo turns AGENTS.md off for Claude.
if [ -f "$root/CLAUDE.local.md" ] && [ ! -f "$root/CLAUDE.md" ] && [ ! -f "$root/.claude/CLAUDE.md" ] \
   && [ -f "$root/AGENTS.md" ] && ! grep -Fxq "$root/AGENTS.md" "$tmp/launch_expanded"; then
  finding blocker local-shadows-agents CLAUDE.local.md "this repo relies on AGENTS.md, and a CLAUDE.local.md makes Claude read CLAUDE.md files only, so AGENTS.md no longer loads; put '@AGENTS.md' on its first line"
fi

# Per-file line limit for everything that loads at launch.
while IFS= read -r f <&3; do
  l="$(n_lines "$f")"
  [ "${l:-0}" -gt "$LINE_LIMIT" ] && finding should launch-lines "$(rel "$f")" "$l lines load every session (docs: keep each CLAUDE.md under $LINE_LIMIT); move area or task detail into on-demand files"
done 3< "$tmp/launch_expanded"

# Imports.
sort -u "$tmp/missing_imports" | while IFS="$(printf '\t')" read -r from t; do
  finding consider import-missing "$(rel "$from")" "'@$t' doesn't resolve, so nothing is imported; if it's a package or handle, wrap it in backticks"
done
sort -u "$tmp/edges" | while IFS="$(printf '\t')" read -r from to; do
  grep -Fxq "$from" "$tmp/launch_expanded" || continue
  b="$(n_bytes "$to")"; b="${b:-0}"
  case "$(basename "$to")" in AGENTS.md) continue ;; esac   # the documented shared-file pattern
  [ "$b" -gt 2000 ] && finding consider import-eager "$(rel "$from")" "@$(rel "$to") adds ~$(tok "$b") tok at launch: imports load with their file, so this costs the same as pasting it in; route to it instead if it's only needed sometimes"
done

# ---- Rules ----------------------------------------------------------------------------------
: > "$tmp/rule_summary"; : > "$tmp/unscoped_rules"; mkdir -p "$tmp/match"
rule_n=0; scoped_n=0; dead_n=0
while IFS= read -r f <&3; do
  rule_n=$(( rule_n + 1 ))
  base="${f%%/.claude/rules/*}"; baserel="$(rel "$base")"; fr="$(rel "$f")"
  awk '
    NR==1 { if ($0 !~ /^---[ \t]*$/) { print "NOFM"; exit } ; fm=1; next }
    fm && /^---[ \t]*$/ { closed=1; exit }
    fm {
      if ($0 ~ /^\t/) bad = "tab indentation"
      if ($0 ~ /^paths:/) { inp=1; v=$0; sub(/^paths:[ \t]*/, "", v); if (v != "") print "STR\t" v; next }
      if ($0 ~ /^[A-Za-z_][A-Za-z0-9_-]*:/) { inp=0; next }
      if (inp && $0 ~ /^[ \t]*-[ \t]*/) { v=$0; sub(/^[ \t]*-[ \t]*/, "", v); print "ITEM\t" v; next }
      if ($0 ~ /^[ \t]*$/ || $0 ~ /^[ \t]*#/) next
      if (inp) bad = "unexpected line under paths: " $0
    }
    END { if (fm && !closed) print "UNCLOSED"; if (bad != "") print "BAD\t" bad }' "$f" > "$tmp/fm"
  if grep -q '^UNCLOSED' "$tmp/fm"; then
    finding should rule-frontmatter "$fr" "frontmatter never closes with '---'; Claude Code may read the whole file as unscoped or skip its paths"
  fi
  bad="$(grep '^BAD' "$tmp/fm" | cut -f2-)"
  # Pattern list: list items, or a comma-separated / [flow] string (commas inside braces kept).
  { grep '^ITEM' "$tmp/fm" | cut -f2-
    grep '^STR' "$tmp/fm" | cut -f2- | sed -e 's/^\[//' -e 's/\]$//' -e 's/^"\([^"]*\)"$/\1/' -e "s/^'\([^']*\)'\$/\\1/" \
      | awk '{ d=0; s=""; for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="{") d++; if (c=="}") d--; if (c=="," && d==0) { print s; s="" } else s=s c } print s }'
  } | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' > "$tmp/pats_raw"
  : > "$tmp/pats"
  while IFS= read -r p <&5; do
    [ -z "$p" ] && continue
    q="$(printf '%s' "$p" | tr -cd "\"'" | wc -c | tr -d ' ')"
    [ $(( q % 2 )) -eq 1 ] && bad="unbalanced quotes in: $p"
    p="$(printf '%s' "$p" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\\1/")"
    printf '%s\n' "$p" >> "$tmp/pats"
  done 5< "$tmp/pats_raw"
  if [ -n "$bad" ]; then
    finding should rule-frontmatter "$fr" "invalid YAML ($bad): Claude Code then loads the rule as if it had no paths, i.e. everywhere"
  fi
  bytes="$(n_bytes "$f")"; chars="$(n_chars "$f")"
  if [ ! -s "$tmp/pats" ] || [ -n "$bad" ]; then
    printf '%s\t%s\t%s\n' "$base" "$f" "$bytes" >> "$tmp/unscoped_rules"
    [ "$base" != "$root" ] && [ "${chars:-0}" -gt "$ONDEMAND_LIMIT" ] && \
      finding blocker ondemand-truncated "$fr" "$chars chars; Claude gets only the first $ONDEMAND_LIMIT when it loads (on demand). Split it"
    continue
  fi
  scoped_n=$(( scoped_n + 1 ))
  [ "${chars:-0}" -gt "$ONDEMAND_LIMIT" ] && finding blocker ondemand-truncated "$fr" "$chars chars; a path-scoped rule is cut off after $ONDEMAND_LIMIT. Split it"
  if [ "$is_git" -eq 0 ]; then continue; fi
  mfile="$tmp/match/$rule_n"; : > "$mfile"; total=0; zero=""; fixes=""
  while IFS= read -r p <&5; do
    c=0
    while IFS= read -r e <&6; do
      glob_files "$base" "$e" > "$tmp/m1"; n="$(wc -l <"$tmp/m1" | tr -d ' ')"; c=$(( c + n ))
      if [ "$baserel" = . ]; then cat "$tmp/m1"; else sed "s|^|$baserel/|" "$tmp/m1"; fi >> "$mfile"
    done 6< <(expand_braces "$p")
    total=$(( total + c ))
    if [ "$c" -eq 0 ]; then
      zero="$zero, $p"
      # Written from the repo root instead of the rule's base folder?
      if [ "$baserel" != . ]; then
        case "$p" in
          "$baserel"/*)
            s="${p#"$baserel"/}"; sc=0
            while IFS= read -r e <&6; do sc=$(( sc + $(glob_files "$base" "$e" | wc -l | tr -d ' ') )); done 6< <(expand_braces "$s")
            [ "$sc" -gt 0 ] && fixes="$fixes; \"$p\" -> \"$s\" ($sc files)" ;;
        esac
      fi
    fi
  done 5< "$tmp/pats"
  zero="${zero#, }"; fixes="${fixes#; }"
  if [ -n "$fixes" ]; then
    finding blocker rule-base "$fr" "paths resolve from $baserel/ (the folder holding .claude/), so these match nothing and the rule never loads for them: $fixes"
  fi
  if [ "$total" -eq 0 ]; then
    dead_n=$(( dead_n + 1 ))
    [ -z "$fixes" ] && finding should rule-dead "$fr" "no file under $baserel/ matches any pattern ($zero), so the rule never loads"
  elif [ -n "$zero" ] && [ -z "$fixes" ]; then
    finding info rule-pattern-empty "$fr" "pattern(s) match no files yet: $zero"
  fi
  sort -u "$mfile" -o "$mfile"
  printf '%s\t%s\t%s\n' "$mfile" "$f" "$bytes" >> "$tmp/rule_summary"
done 3< "$tmp/rules"
[ -n "$(cat "$tmp/rules")" ] && [ "$is_git" -eq 0 ] && finding info no-git . "not a git work tree: rule patterns weren't checked against files"

unscoped_root=0
while IFS="$(printf '\t')" read -r b f by <&3; do
  [ "$b" = "$root" ] && unscoped_root=$(( unscoped_root + by ))
done 3< "$tmp/unscoped_rules"

# ---- Skills ---------------------------------------------------------------------------------
skill_desc_bytes=0
while IFS= read -r f <&3; do
  fr="$(rel "$f")"
  info="$(awk '
    NR==1 && !/^---/ { exit } NR==1 { next } /^---/ { exit }
    /^[A-Za-z_][A-Za-z0-9_-]*:/ {
      k=$0; sub(/:.*/, "", k); v=$0; sub(/^[^:]*:[ \t]*/, "", v)
      cur = (k=="description" || k=="when_to_use") ? k : ""
      if (k=="disable-model-invocation" && v ~ /true/) dmi=1
      if (cur != "" && v !~ /^[>|][-+]?$/) out = out " " v
      next }
    cur != "" { v=$0; sub(/^[ \t]+/, "", v); out = out " " v }
    END { sub(/^ +/, "", out); print (dmi ? "user" : "auto") " " length(out) }' "$f")"
  who="${info%% *}"; dl="${info##* }"
  l="$(n_lines "$f")"
  [ "${dl:-0}" -eq 0 ] && finding should skill-no-description "$fr" "no description, so Claude can't tell when to use it"
  [ "${dl:-0}" -gt "$DESC_LIMIT" ] && finding should skill-description-long "$fr" "description is $dl chars; the skill listing cuts it off at $DESC_LIMIT, so the end never reaches Claude"
  [ "${l:-0}" -gt "$SKILL_LINES" ] && finding consider skill-long "$fr" "$l lines (docs: keep SKILL.md under $SKILL_LINES); move detail into files the skill points to"
  case "$f" in "$root/.claude/skills/"*) [ "$who" = auto ] && skill_desc_bytes=$(( skill_desc_bytes + ${dl:-0} )) ;; esac
done 3< "$tmp/skills"

launch_total=$(( launch_bytes + unscoped_root + skill_desc_bytes ))
[ "$(tok "$launch_total")" -gt "$LAUNCH_BUDGET" ] && finding consider launch-budget "$(head -n1 "$tmp/launch" | cut -f1)" \
  "~$(tok "$launch_total") tok load every session (ICM budget ~$LAUNCH_BUDGET for identity + routing); see the largest sections below"

# ---- Areas: on-demand files, stacked with every file above them -----------------------------
: > "$tmp/area_dirs"
while IFS= read -r f <&3; do
  d="$(ctx_dir "$f")"; [ "$d" = "$root" ] || echo "$d"
done 3< "$tmp/claude" >> "$tmp/area_dirs"
if [ "$mode" = agents ]; then
  while IFS= read -r f <&3; do d="$(ctx_dir "$f")"; [ "$d" = "$root" ] || echo "$d"; done 3< "$tmp/agents" >> "$tmp/area_dirs"
fi
while IFS="$(printf '\t')" read -r b f by <&3; do [ "$b" = "$root" ] || echo "$b"; done 3< "$tmp/unscoped_rules" >> "$tmp/area_dirs"
sort -u "$tmp/area_dirs" -o "$tmp/area_dirs"

: > "$tmp/area_own"   # dir<TAB>bytes this folder adds when Claude works in it
while IFS= read -r d <&3; do
  own=0; have_claude=0
  for n in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md; do
    if [ -f "$d/$n" ]; then
      have_claude=1; b="$(expanded "$d/$n")"; own=$(( own + b ))
      ch=0; while IFS= read -r v <&4; do ch=$(( ch + $(n_chars "$v") )); done 4< "$tmp/visited"
      [ "$ch" -gt "$ONDEMAND_LIMIT" ] && finding blocker ondemand-truncated "$(rel "$d/$n")" \
        "$ch chars with its imports; Claude gets only the first $ONDEMAND_LIMIT when it loads on demand. Split it"
    fi
  done
  if [ "$mode" = agents ] && [ "$have_claude" -eq 0 ] && [ -f "$d/AGENTS.md" ]; then
    own=$(( own + $(expanded "$d/AGENTS.md") ))
  fi
  while IFS="$(printf '\t')" read -r b f by <&4; do [ "$b" = "$d" ] && own=$(( own + by )); done 4< "$tmp/unscoped_rules"
  printf '%s\t%s\n' "$d" "$own" >> "$tmp/area_own"
done 3< "$tmp/area_dirs"

: > "$tmp/areas"   # tokens<TAB>dir<TAB>rule tokens
while IFS="$(printf '\t')" read -r d own <&3; do
  sum=$launch_total; p="$d"
  while [ "$p" != "$root" ] && [ "$p" != / ]; do
    b="$(awk -F'\t' -v k="$p" '$1==k{print $2; exit}' "$tmp/area_own")"
    sum=$(( sum + ${b:-0} )); p="$(dirname "$p")"
  done
  dr="$(rel "$d")"; rb=0
  while IFS="$(printf '\t')" read -r mf _ by <&4; do
    awk -v p="$dr/" 'index($0, p) == 1 { f=1; exit } END { exit !f }' "$mf" && rb=$(( rb + by ))
  done 4< "$tmp/rule_summary"
  printf '%s\t%s\t%s\n' "$(tok "$sum")" "$dr" "$(tok "$rb")" >> "$tmp/areas"
done 3< "$tmp/area_own"
sort -rn "$tmp/areas" -o "$tmp/areas"
over=0
while IFS="$(printf '\t')" read -r t dr rt <&3; do
  [ "$t" -gt "$AREA_BUDGET" ] || continue
  over=$(( over + 1 )); [ "$over" -le 10 ] || continue
  extra=""; [ "$rt" -gt 0 ] && extra=", plus up to ~$rt tok of path-scoped rules"
  finding should area-budget "$dr" "~$t tok load before any work in this folder (launch + every context file above it; ICM budget ~$AREA_BUDGET for a whole stage)$extra"
done 3< "$tmp/areas"

# ---- AGENTS.md that Claude never reads ------------------------------------------------------
cut -f2 "$tmp/edges" | sort -u > "$tmp/imported"
while IFS= read -r a <&3; do
  d="$(ctx_dir "$a")"
  grep -Fxq "$a" "$tmp/imported" && continue
  if [ "$mode" = claude ]; then
    finding blocker agents-unread "$(rel "$a")" "the repo has a root CLAUDE.md, so Claude reads CLAUDE.md files only, and none imports this AGENTS.md; add a CLAUDE.md beside it containing '@AGENTS.md'"
  elif [ "$mode" = agents ] && { [ -f "$d/CLAUDE.md" ] || [ -f "$d/CLAUDE.local.md" ] || [ -f "$d/.claude/CLAUDE.md" ]; }; then
    finding blocker agents-unread "$(rel "$a")" "a CLAUDE.md in the same folder replaces it for Claude and doesn't import it; add '@AGENTS.md' to that CLAUDE.md"
  fi
done 3< "$tmp/agents"

# ---- Same text in more than one Claude-loaded file ------------------------------------------
cat "$tmp/claude" "$tmp/agents" "$tmp/rules" | sort -u > "$tmp/loaded_like"
while IFS= read -r f <&3; do
  body_of "$f" | awk -v F="$(rel "$f")" '
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    { s = tolower($0); gsub(/[`*_>#]/, "", s); sub(/^[ \t]*([-+]|[0-9]+\.)[ \t]+/, "", s)
      gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s)
      if (length(s) >= 60) print s "\t" F }'
done 3< "$tmp/loaded_like" | sort -u | awk -F'\t' '
  $1 == prev { files = files ", " $2; n++; next }
  { if (n > 1) print n "\t" files "\t" prev; prev = $1; files = $2; n = 1 }
  END { if (n > 1) print n "\t" files "\t" prev }' | sort -rn | head -n 8 > "$tmp/dups"
while IFS="$(printf '\t')" read -r n files text <&3; do
  finding consider dup-text "$(echo "$files" | cut -d, -f1)" "same line in $n files ($files): \"$(printf '%s' "$text" | cut -c1-90)...\"; give it one home"
done 3< "$tmp/dups"

# ---- Twins: Claude rules mirrored for another tool ------------------------------------------
norm() { body_of "$1" | sed -e 's/[ \t]*$//' -e 's/\[[^]]*\]([^)]*)/[L](L)/g' | grep -v '^$'; }
twin_ok=0
while IFS= read -r o <&3; do
  case "$o" in *.mdc|*.md) ;; *) continue ;; esac
  norm "$o" > "$tmp/o"; sort -u "$tmp/o" > "$tmp/os"; on="$(wc -l <"$tmp/os" | tr -d ' ')"
  [ "$on" -ge 3 ] || continue
  while IFS= read -r c <&4; do
    norm "$c" > "$tmp/c"
    if cmp -s "$tmp/o" "$tmp/c"; then twin_ok=$(( twin_ok + 1 )); continue; fi
    sort -u "$tmp/c" > "$tmp/cs"; cn="$(wc -l <"$tmp/cs" | tr -d ' ')"
    common="$(comm -12 "$tmp/os" "$tmp/cs" | wc -l | tr -d ' ')"
    mx=$on; [ "$cn" -gt "$mx" ] && mx=$cn
    if [ $(( common * 100 / mx )) -ge 60 ]; then
      diffn="$(diff "$tmp/c" "$tmp/o" | grep -c '^[<>]')"
      finding consider twin-drift "$(rel "$c")" "mirrors $(rel "$o") for another tool but $diffn lines differ (links ignored); bring them back in step"
    fi
  done 4< "$tmp/rules"
done 3< "$tmp/other"

# ---- Claims to re-check, docs nothing routes to ---------------------------------------------
while IFS= read -r f <&3; do
  grep -n -i -E '(^|[^a-z])(until|for now|temporar(y|ily)|todo|fixme|workaround)([^a-z]|$)' "$f" 2>/dev/null \
    | head -n 5 | while IFS= read -r hit; do
      finding info reverify "$(rel "$f"):${hit%%:*}" "time-bound wording in a file that loads every session; check it's still true: $(printf '%s' "${hit#*:}" | cut -c1-100)"
    done
done 3< "$tmp/launch_expanded"

cat "$tmp/claude" "$tmp/agents" "$tmp/rules" "$tmp/skills" "$tmp/contexts" > "$tmp/instr"
for doc in "$root"/*.md "$root/docs"; do
  [ -e "$doc" ] || continue
  b="$(basename "$doc")"
  case "$b" in README.md|CHANGELOG.md|LICENSE*|CLAUDE.md|CLAUDE.local.md|AGENTS.md|CODE_OF_CONDUCT.md|SECURITY.md|GEMINI.md) continue ;; esac
  [ "$b" = docs ] && b="docs/"
  hit=0
  while IFS= read -r f <&3; do grep -Fq -- "$b" "$f" 2>/dev/null && { hit=1; break; }; done 3< "$tmp/instr"
  [ "$hit" -eq 0 ] && finding info unrouted-doc "$b" "no instruction file points to it, so Claude finds it only by searching; add a routing line if agents need it"
done

# ---- Workflow stage contracts ---------------------------------------------------------------
stage_n=0
while IFS= read -r ctx <&3; do
  grep -q '^## Inputs' "$ctx" || continue
  stage_n=$(( stage_n + 1 )); dir="$(dirname "$ctx")"; cr="$(rel "$ctx")"
  stage_inputs "$ctx" | while IFS= read -r t; do
    p="$dir/${t%%#*}"
    if [ ! -f "$p" ]; then
      finding blocker stage-input-missing "$cr" "input '$t' doesn't exist (resolved from the stage folder)"
    else
      case "$t" in *"#"*)
        h="${t#*#}"
        awk -v h="$h" 'BEGIN{h=tolower(h)} /^#+[ \t]/ { s=tolower($0); sub(/^#+[ \t]+/, "", s); sub(/[ \t]+$/, "", s); if (s==h) { f=1; exit } } END { exit !f }' "$p" \
          || finding should stage-anchor-missing "$cr" "input '$t' names a section that isn't a heading in that file" ;;
      esac
    fi
  done
  want="$(stage_hash "$ctx")"
  awk '/^## /{ sec = $0; next } sec ~ /^## Outputs/ && /^[ \t]*[-*][ \t]/ { if (match($0, /`[^`]+`/)) print substr($0, RSTART + 1, RLENGTH - 2) }' "$ctx" \
    | while IFS= read -r t; do
      o="$dir/$t"; [ -f "$o" ] || continue
      have="$(grep -m1 -o 'icm-inputs: [0-9]*-[0-9]*' "$o" 2>/dev/null | sed 's/icm-inputs: //')"
      if [ -z "$have" ]; then finding info stage-unstamped "$(rel "$o")" "no icm-inputs stamp, so staleness can't be checked"
      elif [ "$have" != "$want" ]; then finding should stage-stale "$(rel "$o")" "its stage's inputs changed since it was written (stamp $have, now $want); re-run $(basename "$dir")"
      fi
    done
done 3< "$tmp/contexts"

# ---- Report ---------------------------------------------------------------------------------
printf '# ICM audit: %s\n\n' "$(basename "$root")"
printf 'root: %s · instructions: %s · tokens ~ bytes/4 · budgets: launch %s, area %s\n\n' \
  "$root" "$( [ "$mode" = claude ] && echo 'CLAUDE.md' || { [ "$mode" = agents ] && echo 'AGENTS.md (no CLAUDE.md)' || echo none; } )" \
  "$LAUNCH_BUDGET" "$AREA_BUDGET"

printf '## Launch: loads every session (~%s tok)\n' "$(tok "$launch_total")"
while IFS="$(printf '\t')" read -r f b <&3; do printf -- '- %s with imports: ~%s tok\n' "$f" "$(tok "$b")"; done 3< "$tmp/launch"
[ "$unscoped_root" -gt 0 ] && printf -- '- unscoped rules in .claude/rules: ~%s tok\n' "$(tok "$unscoped_root")"
[ "$skill_desc_bytes" -gt 0 ] && printf -- '- project skill descriptions: ~%s tok\n' "$(tok "$skill_desc_bytes")"
if [ -s "$tmp/launch_expanded" ]; then
  printf '\nLargest sections at launch:\n'
  while IFS= read -r f <&3; do
    awk -v F="$(rel "$f")" '/^## /{ if (h) print n "\t" F "\t" h; h=$0; n=0; next } { n += length($0) + 1 } END { if (h) print n "\t" F "\t" h }' "$f"
  done 3< "$tmp/launch_expanded" | sort -rn | head -n 6 | while IFS="$(printf '\t')" read -r n f h; do
    printf -- '- ~%s tok  %s  %s\n' "$(tok "$n")" "$f" "$h"
  done
fi

printf '\n## Areas: load on demand, stacked with every context file above them\n'
if [ -s "$tmp/areas" ]; then
  head -n 12 "$tmp/areas" | while IFS="$(printf '\t')" read -r t dr rt; do
    if [ "$rt" -gt 0 ]; then printf -- '- ~%s tok  %s  (+ up to ~%s tok of path-scoped rules)\n' "$t" "$dr" "$rt"
    else printf -- '- ~%s tok  %s\n' "$t" "$dr"; fi
  done
else
  echo "- none (no nested context files)"
fi

printf '\n## Inventory\n'
printf -- '- rules: %s (%s path-scoped, %s never load)\n' "$rule_n" "$scoped_n" "$dead_n"
printf -- '- context files: %s CLAUDE family, %s AGENTS.md, %s skills, %s stage contracts\n' \
  "$(wc -l <"$tmp/claude" | tr -d ' ')" "$(wc -l <"$tmp/agents" | tr -d ' ')" "$(wc -l <"$tmp/skills" | tr -d ' ')" "$stage_n"
if [ -s "$tmp/other" ]; then
  printf -- '- other tools: %s files (%s)' "$(wc -l <"$tmp/other" | tr -d ' ')" \
    "$(sed "s|^$root/||" "$tmp/other" | awk -F/ '{ print ($1 == ".cursor" || $1 == ".github" || $1 == ".windsurf") ? $1 "/" $2 : $1 }' | sort -u | tr '\n' ' ' | sed 's/ $//')"
  [ "$twin_ok" -gt 0 ] && printf '; %s mirror a Claude rule exactly' "$twin_ok"
  printf '\n'
fi

printf '\n## Findings\n'
if [ -s "$tmp/findings" ]; then
  sort -t "$(printf '\t')" -k1,1n -s "$tmp/findings" | cut -f2-
else
  echo "none"
fi
exit 0
