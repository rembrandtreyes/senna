#!/usr/bin/env bash
# review-comments.sh <owner/repo> <count> <out.jsonl>
#   Writes the review comments of the <count> most recently merged PRs to <out.jsonl>, one JSON
#   object per line, for /icm learn. Read-only (gh api GETs). Needs gh (authenticated) and jq.
#   - inline:  {"pr", "kind":"inline", "author", "bot", "path", "reply", "body"}
#   - review:  {"pr", "kind":"review", "author", "bot", "state", "body"}   (non-empty bodies only)
#   - a PR with neither: {"pr", "kind":"none"}
#   Bodies are cut at 3000 characters. Portable: bash 3.2, BSD tools.
set -u
repo="${1:-}" count="${2:-}" out="${3:-}"
case "$repo" in */*) ;; *) echo "usage: review-comments.sh <owner/repo> <count> <out.jsonl>" >&2; exit 2 ;; esac
case "$count" in ''|*[!0-9]*) echo "count must be a number" >&2; exit 2 ;; esac
[ -n "$out" ] || { echo "usage: review-comments.sh <owner/repo> <count> <out.jsonl>" >&2; exit 2; }
command -v gh >/dev/null && command -v jq >/dev/null || { echo "review-comments: needs gh and jq" >&2; exit 2; }

prs="$(gh pr list --repo "$repo" --state merged --limit "$count" --json number --jq '.[].number')" \
  || { echo "review-comments: couldn't list merged PRs for $repo" >&2; exit 1; }
: > "$out"
n_inline=0 n_review=0 n_none=0 n_err=0
for pr in $prs; do
  inline="$(gh api --paginate "repos/$repo/pulls/$pr/comments?per_page=100" 2>/dev/null \
    | jq -c --argjson pr "$pr" '.[] | {pr: $pr, kind: "inline", author: (.user.login // ""), bot: ((.user.type // "") == "Bot"),
        path: (.path // ""), reply: (.in_reply_to_id != null), body: ((.body // "")[0:3000])}')" || { n_err=$((n_err + 1)); continue; }
  reviews="$(gh api --paginate "repos/$repo/pulls/$pr/reviews?per_page=100" 2>/dev/null \
    | jq -c --argjson pr "$pr" '.[] | select((.body // "") != "") | {pr: $pr, kind: "review", author: (.user.login // ""),
        bot: ((.user.type // "") == "Bot"), state: (.state // ""), body: ((.body // "")[0:3000])}')" || { n_err=$((n_err + 1)); continue; }
  if [ -z "$inline" ] && [ -z "$reviews" ]; then
    printf '{"pr":%s,"kind":"none"}\n' "$pr" >> "$out"; n_none=$((n_none + 1)); continue
  fi
  [ -n "$inline" ] && { printf '%s\n' "$inline" >> "$out"; n_inline=$((n_inline + $(printf '%s\n' "$inline" | wc -l))); }
  [ -n "$reviews" ] && { printf '%s\n' "$reviews" >> "$out"; n_review=$((n_review + $(printf '%s\n' "$reviews" | wc -l))); }
done
echo "review-comments: $(echo "$prs" | grep -c .) PRs, $n_inline inline, $n_review review bodies, $n_none with none, $n_err errors -> $out"
