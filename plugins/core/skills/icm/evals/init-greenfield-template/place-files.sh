#!/usr/bin/env bash
# Builds a made-up new repo: two apps and a lib with one placeholder file each, and a CLAUDE.md
# copied from a project template that was never filled in.
set -eu
git init -q
mkdir -p apps/web/src apps/api/src libs/shared/src
echo '{"name":"app","private":true,"workspaces":["apps/*","libs/*"],"scripts":{"test":"vitest run","lint":"biome check .","typecheck":"tsc -b"}}' > package.json
{
  echo '# <Project name>'; echo
  echo '<One paragraph: what this is, who uses it, and what matters most.>'; echo
  echo '## Stack & layout'
  echo '- `apps/web` Next.js · `apps/mobile` Expo · `services/api` Go · `crates/engine` Rust   <!-- edit -->'
  echo '- Contract: `contracts/openapi.yaml`. Regenerate with: `<command>`'; echo
  echo '## Commands'; echo '- Dev: `<command>`'; echo '- Test: `<command>`'; echo '- Lint/typecheck: `<command>`'; echo
  echo '## Things that will bite you'; echo '- <non-obvious facts>'
} > CLAUDE.md
echo 'export const Page = () => null;' > apps/web/src/page.tsx
echo 'export const handler = () => 1;' > apps/api/src/handler.ts
echo 'export const id = (x: string) => x;' > libs/shared/src/index.ts
git add -A && git -c user.email=t@example.com -c user.name=t commit -qm init
