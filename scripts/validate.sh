#!/usr/bin/env bash
# Sanity-check the harness repo before pushing.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0
err() { echo "FAIL: $*"; fail=1; }

command -v jq >/dev/null || { echo "jq required"; exit 1; }

while IFS= read -r f; do jq empty "$f" 2>/dev/null || err "invalid JSON: $f"; done \
  < <(find . -name '*.json' -not -path './.git/*')

while IFS= read -r f; do bash -n "$f" 2>/dev/null || err "bash syntax: $f"; done \
  < <(find . -name '*.sh' -not -path './.git/*')

while IFS= read -r f; do [ -x "$f" ] || err "not executable: $f"; done \
  < <(find plugins \( -path '*/hooks/scripts/*.sh' -o -path '*/scripts/*.sh' \) -not -name common.sh)

for f in plugins/*/hooks/scripts/common.sh; do
  cmp -s shared/common.sh "$f" || err "stale copy (run scripts/sync-common.sh): $f"
done

for src in $(jq -r '.plugins[].source' .claude-plugin/marketplace.json); do
  [ -f "$src/.claude-plugin/plugin.json" ] || err "missing plugin.json: $src"
  name="$(jq -r .name "$src/.claude-plugin/plugin.json")"
  mver="$(jq -r --arg s "$src" '.plugins[] | select(.source==$s) | .version' .claude-plugin/marketplace.json)"
  pver="$(jq -r .version "$src/.claude-plugin/plugin.json")"
  [ "$mver" = "$pver" ] || err "version mismatch for $name: marketplace $mver vs plugin $pver"
done

while IFS= read -r f; do
  [ "$(head -n1 "$f")" = "---" ] || err "missing frontmatter: $f"
  grep -q '^description:' "$f" || err "missing description: $f"
done < <(find plugins \( -path '*/agents/*.md' -o -path '*/commands/*.md' -o -name SKILL.md \))

[ $fail -eq 0 ] && echo "All checks passed." || exit 1
