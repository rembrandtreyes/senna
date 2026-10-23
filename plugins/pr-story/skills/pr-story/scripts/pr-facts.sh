#!/usr/bin/env bash
# pr-facts.sh [base-ref] [head-ref]
# The deterministic half of a PR story: base, commits, size, files with change tags, the
# checklists those tags select, ticket refs, fix history of the touched files, and the
# task/spec/ADR/lessons files that exist. Committed changes only (merge-base..head).
# Run it from the project root. Base defaults to origin/HEAD, then origin/main, origin/master,
# main, master. Head defaults to HEAD; pass a SHA to describe a PR that isn't checked out.
# PR_STORY_MAX_LINES (default 400) is the size a reviewer can take in one sitting.
# Read-only. Exit 0 = printed, 2 = usage or setup problem.
set -uo pipefail

case "${1:-}" in -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
git rev-parse --git-dir >/dev/null 2>&1 || { echo "pr-facts: not in a git repository" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)" || exit 2
limit="${PR_STORY_MAX_LINES:-400}"

# Pin the output format against user config (noprefix, color, external diff tools).
g() { git -c core.quotePath=false -c color.ui=never -c diff.noprefix=false -c diff.mnemonicPrefix=false "$@"; }
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
mb="$(git merge-base "$base" "$head" 2>/dev/null)" || { echo "pr-facts: $base and $head share no history" >&2; exit 2; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pr-facts.XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

if [ "$head" = HEAD ]; then
  branch="$(git symbolic-ref -q --short HEAD 2>/dev/null || echo '(detached)')"
else
  branch="$head"
fi
echo "base: $base (merge-base $(git rev-parse --short "$mb"))"
echo "branch: $branch"
n="$(git rev-list --no-merges --count "$mb..$head")"
echo "commits: $n"
g log --no-merges --format='  %h %s' "$mb..$head" | head -n 30
[ "$n" -gt 30 ] && echo "  ... and $((n - 30)) more"

dirty=0
[ "$head" = HEAD ] && dirty="$(git --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
if [ "$n" -eq 0 ]; then
  echo "nothing committed since $base; commit first (uncommitted files: $dirty)"
  exit 0
fi

gd --name-status -M "$mb" "$head" > "$tmp/status"
gd --numstat -M "$mb" "$head" > "$tmp/numstat"

# Content tags: scan changed lines (not context) of each file once. ---/+++ are headers only
# right after "diff --git" (later, "--- x" is a removed line starting with "--"), and git
# appends a tab to them when the path has a space.
gd -U0 -M "$mb" "$head" | awk '
  /^diff --git / { hdr = 1; f = ""; o = ""; next }
  hdr && /^(---|\+\+\+) / { sub(/\t$/, "") }
  hdr && /^--- /     { o = ($0 == "--- /dev/null") ? "" : substr($0, 7); next }
  hdr && /^\+\+\+ /  { f = ($0 == "+++ /dev/null") ? o : substr($0, 7); hdr = 0; next }
  hdr { next }
  /^[+-]/ {
    if (f == "") next
    l = tolower(substr($0, 2))
    if (l ~ /fetch\(|axios|xmlhttprequest|http\.(get|post|newrequest|client)|reqwest|urllib|requests\.(get|post|put|delete)|res\.(status|json|send)\(|router\.(get|post|put|patch|delete)\(|app\.(get|post|put|patch|delete)\(|mapping\(|nextresponse|new response\(/) print f "\thttp"
    if (l ~ /create table|alter table|drop table|add column|drop column|create (unique )?index|insert into|delete from|\.migrate\(|prisma\.|knex\(/) print f "\tdata"
    if (l ~ /promise\.(all|race|allsettled|any)|go func|sync\.(mutex|rwmutex|waitgroup|once)|make\(chan|<-chan|tokio::spawn|spawn_blocking|mutex<|rwlock<|atomic|for update|isolation level|\.lock\(\)|semaphore|worker_threads|new worker\(/) print f "\tconcurrency"
    if (l ~ /password|secret|api[_-]?key|bearer|authoriz|authenticat|jwt|crypto\.|bcrypt|argon2|hmac|sanitiz|dangerouslysetinnerhtml|innerhtml|eval\(|child_process|csrf|set-cookie|httponly|row level security|create policy/) print f "\tsecurity"
    if (l ~ /process\.env|os\.getenv|env::var|getenv\(|feature[_-]?flag/) print f "\tconfig"
  }' | sort -u > "$tmp/ctags"

# Ticket refs from the branch name and commit messages; history of the touched files.
{ echo "$branch"; g log --no-merges --format='%B' "$mb..$head"; } \
  | grep -oE '(^|[^A-Za-z0-9])(#[0-9]+|[A-Z][A-Z0-9]*-[0-9]+)' | sed 's/^[^#A-Z]//' \
  | grep -vE '^(UTF|SHA|ISO|AES|TLS|HTTP|RFC|PR)-' | sort -u | tr '\n' ' ' | sed 's/ $//' > "$tmp/refs"
g log -n 300 --no-merges --format='@@%s' --name-only "$mb" > "$tmp/history" 2>/dev/null

awk -F'\t' -v limit="$limit" -v histfile="$tmp/history" -v ctagfile="$tmp/ctags" -v statusfile="$tmp/status" '
  function newpath(p,   pre, mid, post) {
    if (p ~ /\{.* => .*\}/) {
      pre = p; sub(/\{.*$/, "", pre); post = p; sub(/^[^}]*\}/, "", post)
      mid = p; sub(/^[^{]*\{/, "", mid); sub(/\}.*$/, "", mid); sub(/^.* => /, "", mid)
      p = pre mid post; gsub(/\/\//, "/", p); return p
    }
    if (p ~ / => /) sub(/^.* => /, "", p)
    return p
  }
  function addtag(path, t) { if (index(" " tags[path] " ", " " t " ") == 0) tags[path] = (tags[path] == "" ? t : tags[path] " " t) }
  function pathtags(path,   p) {
    p = tolower(path)
    if (p ~ /(^|\/)(package\.json|go\.mod|cargo\.toml|requirements[^\/]*\.txt|pyproject\.toml|gemfile|podfile|cmakelists\.txt|pom\.xml|build\.gradle(\.kts)?)$/) { addtag(path, "config"); return }
    if (p ~ /\.(md|mdx|rst|adoc|txt)$/ || p ~ /(^|\/)docs?\//) { addtag(path, "docs"); return }
    if (p ~ /(^|\/)(tests?|__tests__|e2e|cypress|playwright)\// || p ~ /\.(test|spec)\.[a-z]+$/ || p ~ /_test\.(go|py)$/ || p ~ /(^|\/)test_[^\/]*\.py$/) { addtag(path, "tests"); return }
    if (p ~ /(^|\/)(migrations?|migrate|seeds?|schema)\// || p ~ /\.(sql|prisma)$/) addtag(path, "data")
    if (p ~ /(^|\/)(api|apis|routes?|handlers?|controllers?|endpoints?|middleware|graphql)\// || p ~ /\.(proto|graphql|gql)$/ || p ~ /openapi|swagger/ || p ~ /(^|\/)route\.(ts|js)$/) addtag(path, "http")
    if (p ~ /\.(tsx|jsx|vue|svelte|css|scss|sass|less|html)$/ || p ~ /(^|\/)(components?|screens|pages)\//) addtag(path, "ui")
    if (p ~ /auth([^o]|$)|login|session|passw|secret|crypt|permission|rbac|(^|[^a-z])acls?([^a-z]|$)|polic|jwt|csrf|cors|sanitiz/ || p ~ /(^|\/)\.env/) addtag(path, "security")
    if (p ~ /(^|\/)(dockerfile|docker-compose[^\/]*|makefile|procfile|vercel\.json|netlify\.toml|fly\.toml|app\.json|eas\.json)$/ || p ~ /(^|\/)(\.github|\.gitlab|terraform|infra|deploy|k8s|helm)\// || p ~ /\.(tf|tfvars|ya?ml|toml|ini|conf)$/ || p ~ /(^|\/)app\.config\.[jt]s$/) addtag(path, "config")
  }
  function skipsize(p) {
    p = tolower(p)
    return (p ~ /(^|\/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?|cargo\.lock|go\.sum|poetry\.lock|gemfile\.lock|podfile\.lock|composer\.lock)$/ || p ~ /\.(min\.js|min\.css|map|snap|pb\.go)$/ || p ~ /(^|\/)(dist|build|vendor|generated|__generated__|\.next)\// || p ~ /[._]generated\./)
  }
  FILENAME == ctagfile { ct[$1] = (ct[$1] == "" ? $2 : ct[$1] " " $2); next }
  FILENAME == histfile {
    if ($0 ~ /^@@/) { s = tolower(substr($0, 3)); isfix = (s ~ /^(fix|hotfix|bugfix|bug)([^a-z]|$)|^revert|(^|[^a-z])fix(es|ed)?([^a-z]|$)/); isrev = (s ~ /^revert/); next }
    if ($0 != "" && isfix) { fixes[$0]++; if (isrev) reverts[$0]++ }
    next
  }
  FILENAME == statusfile { st = substr($1, 1, 1); np = $NF; status[np] = st; if (st == "R" || st == "C") old[np] = $2; next }
  {
    path = newpath($3); a = $1; d = $2; nfiles++
    pathtags(path)
    if (!skipsize(path) && tags[path] !~ /docs|tests/ && ct[path] != "") { k = split(ct[path], arr, " "); for (i = 1; i <= k; i++) addtag(path, arr[i]) }
    k = split(tags[path], arr, " "); for (i = 1; i <= k; i++) { cnt[arr[i]]++; if (!(arr[i] in seen)) { seen[arr[i]] = 1; order[++norder] = arr[i] } }
    if (tags[path] !~ /docs|tests/) code++
    if (a == "-") { bin++; shown = "bin" }
    else if (skipsize(path)) { skipf++; skipl += a + d; shown = "+" a " -" d " (not counted)" }
    else { add += a; del += d; shown = "+" a " -" d }
    name = (path in old) ? old[path] " -> " path : path
    line[nfiles] = sprintf("  %-2s %-22s %s%s", status[path], shown, name, tags[path] == "" ? "" : "  [" tags[path] "]")
    nf = fixes[path]; nr = reverts[path]
    if (path in old) { nf += fixes[old[path]]; nr += reverts[old[path]] }
    if (nf > 0) hist[++nhist] = sprintf("  %s: %d fix commit%s%s", path, nf, nf == 1 ? "" : "s", nr > 0 ? " (" nr " revert" (nr == 1 ? "" : "s") ")" : "")
  }
  END {
    if (nfiles == 0) { print "size: 0 changed lines; no net change against the base (the commits cancel out)"; print "checklists: none"; exit }
    total = add + del
    printf "size: %d changed lines (+%d -%d) in %d files; limit %d: %s\n", total, add, del, nfiles, limit, (total > limit ? "OVER, propose a split along the story'\''s seams" : "ok")
    if (skipf > 0 || bin > 0) printf "  not counted: %d lockfile/generated file(s), %d lines; %d binary\n", skipf, skipl, bin
    print "files (status, lines, path, tags):"
    for (i = 1; i <= nfiles; i++) print line[i]
    t = ""; for (i = 1; i <= norder; i++) t = t (t == "" ? "" : ", ") order[i] " (" cnt[order[i]] ")"
    print "tags: " (t == "" ? "none" : t)
    c = "core"; split("http data concurrency security ui config", want, " ")
    for (i = 1; i <= 6; i++) if (want[i] in seen) c = c ", " want[i]
    if (code == 0) c = c " (" ((("tests" in seen) && !("docs" in seen)) ? "tests only" : (("docs" in seen) && !("tests" in seen)) ? "docs only" : "tests and docs only") ")"
    print "checklists: " c
    if (nhist > 0) { print "history (fix commits touching these files, last 300 commits on base):"; for (i = 1; i <= nhist && i <= 8; i++) print hist[i] }
  }' "$tmp/ctags" "$tmp/history" "$tmp/status" "$tmp/numstat"

refs="$(cat "$tmp/refs")"
echo "refs: ${refs:-none}"

# Project files as of head: the working tree when head is HEAD, else the commit.
rd() { if [ "$head" = HEAD ]; then cat -- "$1" 2>/dev/null; else git show "$head:$1" 2>/dev/null; fi; }
lsdir() {
  if [ "$head" = HEAD ]; then for f in "$1"/*; do [ -f "$f" ] && echo "$f"; done
  else g ls-tree --name-only "$head" "$1/" 2>/dev/null; fi
}

echo "context:"
task=""
if [ "$head" = HEAD ] && [ -f .harness/current-task ]; then
  t="$(head -n1 .harness/current-task | tr -d '\r')"
  [ -f "$t" ] && task="$t"
fi
if [ -z "$task" ]; then
  nums="$(printf '%s\n' $refs | sed -n 's/^T-0*\([0-9][0-9]*\)$/\1/p' | tr '\n' ' ')"
  if [ -n "$nums" ]; then
    task="$(lsdir tasks | awk -v nums=" $nums" '{
      f = $0; sub(/^tasks\//, "", f)
      if (match(f, /^T-[0-9]+-/) && index(nums, " " (substr(f, 3, RLENGTH - 3) + 0) " ")) { print $0; exit }
    }')"
  fi
fi
if [ -n "$task" ]; then
  tbody="$(rd "$task")"
  tstatus="$(printf '%s\n' "$tbody" | grep -m1 -E '^Status:' | sed 's/^Status:[[:space:]]*//; s/[[:space:]]*#.*$//')"
  treq="$(printf '%s\n' "$tbody" | grep -m1 -E '^Requirements:' | sed 's/^Requirements:[[:space:]]*//; s/[[:space:]]*#.*$//')"
  echo "  task: $task (Status: ${tstatus:-?}${treq:+; Requirements: $treq})"
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
