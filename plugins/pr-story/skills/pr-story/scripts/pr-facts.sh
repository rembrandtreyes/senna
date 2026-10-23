#!/usr/bin/env bash
# pr-facts.sh [base-ref] [head-ref] [head-branch-name]
# The deterministic half of a PR story: base, commits, size, files with change tags, the
# checklists those tags select, ticket refs, fix history of the touched files, and the
# task/spec/ADR/lessons files that exist. Committed changes only (merge-base..head).
# Run it from the project root. Base defaults to origin/HEAD, then origin/main, origin/master,
# main, master. Head defaults to HEAD; for a PR that isn't checked out, pass its head SHA and
# its branch name (the branch name carries ticket and task refs).
# PR_STORY_MAX_LINES (default 400) is the size a reviewer can take in one sitting.
# Read-only. Exit 0 = printed, 2 = usage or setup problem.
set -uo pipefail
# Byte semantics: every pattern here is ASCII, and awk's tolower() aborts on invalid UTF-8.
export LC_ALL=C

case "${1:-}" in -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
git rev-parse --git-dir >/dev/null 2>&1 || { echo "pr-facts: not in a git repository" >&2; exit 2; }
top="$(git rev-parse --show-toplevel 2>/dev/null)"
{ [ -n "$top" ] && cd "$top"; } || { echo "pr-facts: run it from a work tree, not .git or a bare repo" >&2; exit 2; }
limit="${PR_STORY_MAX_LINES:-400}"
case "$limit" in ''|*[!0-9]*) echo "pr-facts: PR_STORY_MAX_LINES must be a whole number; using 400" >&2; limit=400 ;; esac

# Pin the output format against user config (noprefix, color, external diff tools, signatures).
g() { git -c core.quotePath=false -c color.ui=never -c diff.noprefix=false -c diff.mnemonicPrefix=false -c log.showSignature=false "$@"; }
gd() { g diff --no-color --no-ext-diff --no-textconv --src-prefix=a/ --dst-prefix=b/ "$@"; }
isref() { git rev-parse -q --verify "$1^{commit}" >/dev/null 2>&1; }

base="${1:-}"
if [ -z "$base" ]; then
  for b in "$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" \
           origin/main origin/master main master; do
    if [ -n "$b" ] && isref "$b"; then base="$b"; break; fi
  done
fi
[ -n "$base" ] || { echo "pr-facts: no base branch found; pass one: pr-facts.sh <base-ref>" >&2; exit 2; }
head="${2:-HEAD}"
for r in "$base" "$head"; do isref "$r" || { echo "pr-facts: unknown ref: $r" >&2; exit 2; }; done
if ! mb="$(git merge-base "$base" "$head" 2>/dev/null)"; then
  if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then
    echo "pr-facts: shallow clone, so the merge-base is missing; deepen it (git fetch --unshallow)" >&2
  else
    echo "pr-facts: $base and $head share no history" >&2
  fi
  exit 2
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pr-facts.XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

if [ -n "${3:-}" ]; then
  branch="$3"
elif [ "$head" = HEAD ]; then
  branch="$(git symbolic-ref -q --short HEAD 2>/dev/null || echo '(detached)')"
else
  branch="$head"
fi
echo "base: $base (merge-base $(git rev-parse --short "$mb"))"
echo "branch: $branch"
n="$(git rev-list --no-merges --count "$mb..$head")"
nm="$(git rev-list --merges --count "$mb..$head")"
if [ "$nm" -gt 0 ]; then echo "commits: $n (+$nm merge)"; else echo "commits: $n"; fi
g log --no-merges --format='  %h %s' "$mb..$head" | head -n 30
[ "$n" -gt 30 ] && echo "  ... and $((n - 30)) more"

dirty=0
[ "$head" = HEAD ] && dirty="$(git --no-optional-locks status --porcelain --untracked-files=normal 2>/dev/null | wc -l | tr -d ' ')"
if [ $((n + nm)) -eq 0 ]; then
  echo "nothing committed on $branch since $base${dirty:+ (uncommitted files: $dirty)}"
  exit 0
fi

# One diff run for raw and numstat, so their lines pair up by position (paths come from raw,
# which never rewrites them the way numstat's "a => b" and "{x => y}" rename forms do).
gd --raw --numstat --no-abbrev -M "$mb" "$head" > "$tmp/diff"

# Paths .gitattributes marks generated or vendored don't count toward size.
awk -F'\t' '/^:/ { print $NF }' "$tmp/diff" | {
  if [ "$head" = HEAD ]; then git check-attr --stdin linguist-generated linguist-vendored
  else git check-attr --source="$head" --stdin linguist-generated linguist-vendored 2>/dev/null; fi
} | sed -nE 's/: linguist-(generated|vendored): (set|true)$//p' > "$tmp/attrs"

# Content tags: scan changed lines (not context) of each file once. ---/+++ are headers only
# right after "diff --git" (later, "--- x" is a removed line starting with "--"). git appends
# a tab to them when the path has a space, and C-quotes paths with quotes or control bytes.
gd -U0 -M "$mb" "$head" | awk '
  /^diff --git / { hdr = 1; f = ""; o = ""; next }
  hdr && /^(---|\+\+\+) / {
    sub(/\t$/, ""); p = substr($0, 5)
    if (p ~ /^"[ab]\//) p = "\"" substr(p, 4); else if (p != "/dev/null") p = substr(p, 3)
  }
  hdr && /^--- /    { o = (p == "/dev/null") ? "" : p; next }
  hdr && /^\+\+\+ / { f = (p == "/dev/null") ? o : p; hdr = 0; next }
  hdr { next }
  /^[+-]/ {
    if (f == "") next
    l = tolower(substr($0, 2))
    if (index(l, "base64,") || (length(l) > 300 && index(l, " ") == 0)) next
    if (l ~ /fetch\(|axios|xmlhttprequest|http\.(get|post|newrequest|client)|reqwest|urllib|requests\.(get|post|put|delete)|res\.(status|json|send)\(|router\.(get|post|put|patch|delete)\(|app\.(get|post|put|patch|delete)\(|mapping\(|nextresponse|new response\(/) print f "\thttp"
    if (l ~ /create table|alter table|drop table|add column|drop column|create (unique )?index|insert into|delete from|\.migrate\(|prisma\.|knex\(/) print f "\tdata"
    if (l ~ /promise\.(all|race|allsettled|any)|go func|sync\.(mutex|rwmutex|waitgroup|once)|make\(chan|<-chan|tokio::spawn|spawn_blocking|mutex<|rwlock<|atomic|for update|isolation level|\.lock\(\)|semaphore|worker_threads|new worker\(/) print f "\tconcurrency"
    if (l ~ /password|secret|api[_-]?key|bearer|authoriz|authenticat|jwt|crypto\.|bcrypt|argon2|hmac|sanitiz|dangerouslysetinnerhtml|innerhtml|(^|[^a-z0-9_])eval\(|child_process|csrf|set-cookie|httponly|row level security|create policy/) print f "\tsecurity"
    if (l ~ /process\.env|os\.getenv|env::var|getenv\(|feature[_-]?flag/) print f "\tconfig"
  }' | sort -u > "$tmp/ctags"

# Ticket refs, one per line: the branch name first, then commit messages.
{ printf '%s\n' "$branch"; g log --no-merges --format='%B' "$mb..$head"; } | awk '
  { s = $0
    while (match(s, /#[0-9]+|[A-Za-z][A-Za-z0-9]*-[0-9]+/)) {
      pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
      tok = substr(s, RSTART, RLENGTH); post = substr(s, RSTART + RLENGTH, 1)
      s = substr(s, RSTART + RLENGTH)
      if (pre ~ /[A-Za-z0-9]/ || post ~ /[A-Za-z0-9]/) continue
      if (NR == 1 && tok ~ /^t-[0-9]+$/) tok = "T" substr(tok, 2)
      if (tok ~ /^#/) { if (length(tok) > 6) continue }
      else if (tok !~ /^[A-Z][A-Z0-9]*-/ || tok ~ /^(UTF|SHA|ISO|AES|TLS|HTTP|RFC|PR|CVE|ES|GPT|PEP|ECMA|IPV|MD|X)-/) continue
      if (!(tok in seen)) { seen[tok] = 1; print tok }
    }
  }' > "$tmp/refs"
g log -n 300 --no-merges --format='%x01%h %s' --name-only "$mb" > "$tmp/history" 2>/dev/null

awk -F'\t' -v limit="$limit" '
  function unq(p) { if (p ~ /^".*"$/) p = substr(p, 2, length(p) - 2); return tolower(p) }
  function addtag(path, t) { if (index(" " tags[path] " ", " " t " ") == 0) tags[path] = (tags[path] == "" ? t : tags[path] " " t) }
  function skipsize(p) {
    p = unq(p)
    return (p ~ /(^|\/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?|cargo\.lock|go\.sum|poetry\.lock|gemfile\.lock|podfile\.lock|composer\.lock)$/ || p ~ /\.(min\.js|min\.css|map|snap|pb\.go)$/ || p ~ /(^|\/)(dist|build|vendor|generated|__generated__|\.next)\// || p ~ /[._]generated\./)
  }
  function isasset(p) { return unq(p) ~ /\.svg$/ }
  # Version manifests ride along with most fixes, so their fix history is noise.
  function nohist(p) { return skipsize(p) || unq(p) ~ /(^|\/)(package\.json|plugin\.json|marketplace\.json|cargo\.toml|pyproject\.toml|go\.mod|changelog[^\/]*|version(\.[a-z]+)?)$/ }
  function pathtags(path,   p) {
    if (skipsize(path)) return
    p = unq(path)
    # Prompt files are behaviour for an agent, not documentation.
    if (p ~ /(^|\/)(skill|claude|agents|gemini)\.md$/ || p ~ /(^|\/)(\.claude|commands|agents|skills|prompts)\/.*\.md$/ || p ~ /\.prompt\.md$|(^|\/)copilot-instructions\.md$|(^|\/)\.cursorrules$/) { addtag(path, "prompt"); return }
    if (p ~ /(^|\/)(package\.json|go\.mod|cargo\.toml|requirements[^\/]*\.txt|pyproject\.toml|gemfile|podfile|cmakelists\.txt|pom\.xml|build\.gradle(\.kts)?)$/) { addtag(path, "config"); return }
    if (p ~ /\.(md|mdx|rst|adoc|txt)$/ || (p ~ /(^|\/)docs?\// && p ~ /\.(png|jpe?g|gif|svg|webp)$/)) { addtag(path, "docs"); return }
    if (p ~ /(^|\/)(tests?|__tests__|e2e|cypress|playwright)\// || p ~ /\.(test|spec)\.[a-z]+$/ || p ~ /_test\.(go|py)$/ || p ~ /(^|\/)test_[^\/]*\.py$/) { addtag(path, "tests"); return }
    if (p ~ /(^|\/)(migrations?|migrate|seeds?|schema)\// || p ~ /\.(sql|prisma)$/) addtag(path, "data")
    if (p ~ /(^|\/)(api|apis|routes?|handlers?|controllers?|endpoints?|middleware|graphql)\// || p ~ /\.(proto|graphql|gql)$/ || p ~ /openapi|swagger/ || p ~ /(^|\/)route\.(ts|js)$/) addtag(path, "http")
    if (p ~ /\.(tsx|jsx|vue|svelte|css|scss|sass|less|html|svg)$/ || p ~ /(^|\/)(components?|screens|pages)\//) addtag(path, "ui")
    if (p ~ /auth([^o]|$)|authori[sz]|login|session|passw|secret|crypt|permission|rbac|(^|[^a-z])acls?([^a-z]|$)|polic|jwt|csrf|cors|sanitiz/ || p ~ /(^|\/)\.env/) addtag(path, "security")
    if (p ~ /(^|\/)(dockerfile|docker-compose[^\/]*|makefile|procfile|vercel\.json|netlify\.toml|fly\.toml|app\.json|eas\.json)$/ || p ~ /(^|\/)(\.github|\.gitlab|terraform|infra|deploy|k8s|helm)\// || p ~ /\.(tf|tfvars|ya?ml|toml|ini|conf)$/ || p ~ /(^|\/)app\.config\.[jt]s$/) addtag(path, "config")
  }
  # The files are compared to ARGV, not -v values, so backslashes in TMPDIR survive.
  FILENAME == ARGV[1] { ct[$1] = (ct[$1] == "" ? $2 : ct[$1] " " $2); next }
  FILENAME == ARGV[2] {
    if (substr($0, 1, 1) == "\001") {
      c = substr($0, 2); s = tolower(c); sub(/^[^ ]* /, "", s)
      isfix = (s ~ /^(fix|hotfix|bugfix|bug)([^a-z]|$)|^revert|(^|[^a-z])fix(es|ed|ing)?([^a-z]|$)/); isrev = (s ~ /^revert/); next
    }
    if ($0 != "" && isfix) { fixes[$0]++; if (isrev) reverts[$0]++; if (fixes[$0] <= 3) fixlog[$0] = fixlog[$0] "\n    " c }
    next
  }
  FILENAME == ARGV[3] { gen[$0] = 1; next }
  /^:/ {
    nraw++; split($1, m, " "); st[nraw] = substr(m[5], 1, 1); blob[nraw] = m[4]
    if (NF >= 3) { op[nraw] = $2; np[nraw] = $3 } else { op[nraw] = ""; np[nraw] = $2 }
    next
  }
  { nnum++; na[nnum] = $1; nd[nnum] = $2 }
  END {
    if (nraw == 0) { print "size: 0 changed lines; no net change against the base (the commits cancel out)"; print "checklists: none"; exit }
    for (i = 1; i <= nraw; i++) {
      path = np[i]; a = na[i]; d = nd[i]
      pathtags(path)
      if (!skipsize(path) && !isasset(path) && tags[path] !~ /docs|tests|prompt/ && ct[path] != "") { k = split(ct[path], arr, " "); for (j = 1; j <= k; j++) addtag(path, arr[j]) }
      k = split(tags[path], arr, " "); for (j = 1; j <= k; j++) { cnt[arr[j]]++; if (!(arr[j] in seen)) { seen[arr[j]] = 1; order[++norder] = arr[j] } }
      if (tags[path] !~ /docs|tests/) code++
      # Identical new content in several files (synced copies) is reviewed once. Small files
      # (an __init__.py, a one-line stub) are often identical by chance, so they always count.
      dup = ""
      if (st[i] != "D" && a != "-" && a + d >= 10) { if (blob[i] in firstb) dup = firstb[blob[i]]; else firstb[blob[i]] = path }
      if (a == "-") { bin++; shown = "bin" }
      else if (skipsize(path) || (path in gen) || isasset(path) || dup != "") { skipf++; skipl += a + d; shown = "+" a " -" d " (not counted)" }
      else {
        add += a; del += d; shown = "+" a " -" d
        if (tags[path] ~ /docs/) kd += a + d; else if (tags[path] ~ /tests/) kt += a + d; else kc += a + d
      }
      name = (op[i] != "") ? op[i] " -> " path : path
      if (dup != "") name = name " (same content as " dup ")"
      line[i] = sprintf("  %-2s %-22s %s%s", st[i], shown, name, tags[path] == "" ? "" : "  [" tags[path] "]")
      if (nohist(path)) continue
      nf = fixes[path]; nr = reverts[path]; fl = fixlog[path]
      if (op[i] != "") { nf += fixes[op[i]]; nr += reverts[op[i]]; fl = fl fixlog[op[i]] }
      if (nf > 0) {
        h = sprintf("  %s: %d fix commit%s%s", path, nf, nf == 1 ? "" : "s", nr > 0 ? " (" nr " revert" (nr == 1 ? "" : "s") ")" : "")
        k = split(substr(fl, 2), arr, "\n"); for (j = 1; j <= k && j <= 3; j++) h = h "\n" arr[j]
        # Insertion sort, most fixes first.
        for (j = ++nhist; j > 1 && hn[j - 1] < nf; j--) { hn[j] = hn[j - 1]; hl[j] = hl[j - 1] }
        hn[j] = nf; hl[j] = h
      }
    }
    total = add + del
    printf "size: %d changed lines (+%d -%d) in %d files; limit %d: %s\n", total, add, del, nraw, limit, (total > limit ? "OVER" : "ok")
    printf "  by kind: code %d, tests %d, docs %d\n", kc, kt, kd
    if (skipf > 0 || bin > 0) printf "  not counted: %d lockfile/generated/asset/duplicate file(s), %d lines; %d binary\n", skipf, skipl, bin
    if (nnum != nraw) print "  warning: raw and numstat diffs disagree, so line counts may be off"
    print "files (status, lines, path, tags):"
    for (i = 1; i <= nraw && i <= 60; i++) print line[i]
    if (nraw > 60) print "  ... and " (nraw - 60) " more files (counted above; git diff --stat for the list)"
    t = ""; for (i = 1; i <= norder; i++) t = t (t == "" ? "" : ", ") order[i] " (" cnt[order[i]] ")"
    print "tags: " (t == "" ? "none" : t)
    c = "core"; split("http data concurrency security ui config", want, " ")
    for (i = 1; i <= 6; i++) if (want[i] in seen) c = c ", " want[i]
    if (code == 0) c = c " (" ((("tests" in seen) && !("docs" in seen)) ? "tests only" : (("docs" in seen) && !("tests" in seen)) ? "docs only" : "tests and docs only") ")"
    print "checklists: " c
    if (nhist > 0) {
      print "history (fix commits on the base that touched these files, newest first, of the last 300):"
      for (i = 1; i <= nhist && i <= 8; i++) print hl[i]
      if (nhist > 8) print "  ... and " (nhist - 8) " more files with fix history"
    }
  }' "$tmp/ctags" "$tmp/history" "$tmp/attrs" "$tmp/diff"

refs="$(tr '\n' ' ' < "$tmp/refs" | sed 's/ $//')"
echo "refs: ${refs:-none}"

# Project files as of head: the working tree when head is HEAD, else the commit.
rd() { if [ "$head" = HEAD ]; then cat -- "$1" 2>/dev/null; else git show "$head:$1" 2>/dev/null; fi; }
lsdir() {
  if [ "$head" = HEAD ]; then for f in "$1"/*; do [ -f "$f" ] && echo "$f"; done
  else g ls-tree --name-only "$head" "$1/" 2>/dev/null; fi
}

echo "context:"
task=""; ctnote=""; others=""
if [ "$head" = HEAD ] && [ -f .harness/current-task ]; then
  bom="$(printf '\357\273\277')"
  t="$(tr -d '\r' < .harness/current-task | sed "s/^$bom//; s/^[[:space:]]*//; s/[[:space:]]*\$//" | grep -m1 -v '^$')"
  case "$t" in
    ''|/*|..*|*/../*) ctnote="  .harness/current-task ignored: '${t}' isn't a path inside the repo" ;;
    *) if [ -f "$t" ]; then task="$t"; else ctnote="  .harness/current-task ignored: $t doesn't exist"; fi ;;
  esac
fi
[ -n "$ctnote" ] && echo "$ctnote"
if [ -z "$task" ]; then
  # Branch refs first, so a ticket mentioned in a commit body can't override the branch's own.
  nums="$(awk '$0 ~ /^T-[0-9]+$/ { n = substr($0, 3) + 0; if (!(n in s)) { s[n] = 1; printf "%s ", n } }' "$tmp/refs")"
  if [ -n "$nums" ]; then
    tlist="$(lsdir tasks)"; matches=""
    for num in $nums; do
      matches="$(printf '%s\n' "$tlist" | awk -v n="$num" '{
        f = $0; sub(/^tasks\//, "", f)
        if (match(f, /^T-[0-9]+[-.]/) && substr(f, 3, RLENGTH - 3) + 0 == n) print $0
      }')"
      [ -n "$matches" ] && break
    done
    task="$(printf '%s\n' "$matches" | sed -n 1p)"
    others="$(printf '%s\n' "$matches" | sed 1d | tr '\n' ' ' | sed 's/ $//')"
  fi
fi
if [ -n "$task" ]; then
  tbody="$(rd "$task" | tr -d '\r')"
  tstatus="$(printf '%s\n' "$tbody" | grep -m1 -E '^Status:' | sed 's/^Status:[[:space:]]*//; s/[[:space:]]*#.*$//')"
  treq="$(printf '%s\n' "$tbody" | grep -m1 -E '^Requirements:' | sed 's/^Requirements:[[:space:]]*//; s/[[:space:]]*#.*$//')"
  echo "  task: $task (Status: ${tstatus:-?}${treq:+; Requirements: $treq})"
  [ -n "$others" ] && echo "  also matches: $others (picked the first; check which is meant)"
  spec="$(printf '%s\n' "$tbody" | grep -m1 -E '^Spec:' | grep -oE '[^[:space:],#]+\.md' | head -n1)"
  if [ -n "$spec" ] && [ -n "$(rd "$spec")" ]; then
    echo "  spec: $spec"
    adrs="$(lsdir "$(dirname "$spec")/adr" | grep '\.md$' | awk '{ printf "%s%s", (NR > 1 ? ", " : ""), $0 }')"
    [ -n "$adrs" ] && echo "  adrs: $adrs"
  fi
else
  echo "  task: none found (no .harness/current-task, no T-<n> ref matching tasks/)"
fi
lessons="$(rd .harness/learnings.md)"
if [ -n "$lessons" ]; then
  echo "  lessons: .harness/learnings.md, $(printf '%s\n' "$lessons" | grep -c '\[review\]') [review] of $(printf '%s\n' "$lessons" | grep -c '^- ') entries"
fi
[ "$dirty" -gt 0 ] && echo "uncommitted: $dirty file(s) changed but not committed; they are not part of this story"
exit 0
