#!/usr/bin/env bash
# Live check of /vet, which no fixture can test: it runs agents and researches on the web. One
# headless session in a throwaway repo whose branch breaks a decision record (a default export,
# against "named exports only") and uses an API its React version removed (ReactDOM.render,
# gone in React 19). Takes several minutes and uses your Claude account. Not run by validate.sh.
# Exit 0 = all pass, 1 = a check failed.
set -uo pipefail
command -v claude >/dev/null || { echo "live vet: claude not on PATH, skipped"; exit 0; }
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES CLAUDE_PROJECT_DIR
plugin="$(cd "$(dirname "$0")/../../.." && pwd)/plugins/core"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/vet-live.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT; [ -n "${KEEP:-}" ] && echo "fixture: $tmp"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
fails=0

r="$tmp/repo"; mkdir -p "$r/docs/adr" "$r/src" && cd "$r" || exit 1
git init -q && git symbolic-ref HEAD refs/heads/main
git config user.email t@example.com && git config user.name t && git config commit.gpgsign false
printf '{\n  "name": "app",\n  "private": true,\n  "dependencies": { "react": "^19.1.0", "react-dom": "^19.1.0" }\n}\n' > package.json
printf '{\n  "name": "app",\n  "lockfileVersion": 3,\n  "packages": {\n    "node_modules/react": { "version": "19.1.0" },\n    "node_modules/react-dom": { "version": "19.1.0" }\n  }\n}\n' > package-lock.json
cat > docs/adr/001-named-exports-only.md <<'EOF'
# ADR-001: Named exports only

Status: accepted   ·   Date: 2026-10-01
Applies to: src/**
Check: an `export default` in src/

## Context
Default exports get renamed at each import, so a component has a different name in every file.

## Decision
We will use named exports for everything in src/.
EOF
printf 'export function greet(name) {\n  return `Hello ${name}`\n}\n' > src/greet.js
git add -A && git commit -qm init && git checkout -q -b feat/mount
printf 'export default function App() {\n  return <h1>Hi</h1>\n}\n' > src/App.jsx
printf "import ReactDOM from 'react-dom'\nimport App from './App'\n\nReactDOM.render(<App />, document.getElementById('root'))\n" > src/main.jsx
git add -A && git commit -qm "Mount the app"

(cd "$r" && echo "/vet main" | claude -p --plugin-dir "$plugin" --permission-mode acceptEdits \
  --allowedTools 'Bash(git:*),Bash(mkdir:*),Read,Grep,Glob,Write,WebSearch,WebFetch,Agent,Task' > reply.txt 2>&1)

check() { eval "$2" || { echo "FAIL: $1"; fails=$((fails + 1)); }; }
says() { grep -qiE -- "$1" "$r/reply.txt"; }
check "the diff was written for the research agent" '[ -s "$r/.harness/vet/feat__mount.diff" ]'
check "the broken decision record is named" 'says "ADR-001" && says "App\.jsx"'
check "the removed API is caught" 'says "ReactDOM\.render" && says "createRoot"'
check "practice is backed by a source" 'says "https://[^ ]*react"'
check "verdict FIX FIRST" 'says "FIX FIRST"'
if [ "$fails" -gt 0 ]; then echo "live vet: $fails of 5 checks failed (reply: $r/reply.txt; rerun with KEEP=1)"; exit 1; fi
echo "live vet: 5 checks passed"
