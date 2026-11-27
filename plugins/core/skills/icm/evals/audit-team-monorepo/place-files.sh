#!/usr/bin/env bash
# Builds a made-up monorepo whose agent context has the problems this case looks for.
set -eu
git init -q
mkdir -p apps/web/src apps/web/.claude/rules apps/api/src .cursor/rules
echo '{"name":"shop","private":true,"workspaces":["apps/*"]}' > package.json
echo '@AGENTS.md' > CLAUDE.md
{
  echo '# Shop monorepo'; echo; echo 'A web storefront (apps/web, React) and an API (apps/api, Node).'
  echo; echo '## Commands'; echo '- `npm test -w <app>` runs one app'"'"'s tests.'; echo '- `npm run lint` from the root.'
  echo; echo '## Cursor background agent setup'
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do echo "- Cursor cloud step $i: install the workspace with npm ci --workspace=<app> and keep the proxy settings in .cursor/environment.json."; done
  echo; echo '## Web components'
  for c in Button Card Modal Tabs Table Toast Tooltip Menu Avatar Badge Select Checkbox Radio Slider Spinner; do
    echo "### $c"; echo "- $c takes a variant prop (primary, secondary, ghost) and a size prop (sm, md, lg)."
    echo "- Compose $c from primitives; never restyle it with inline styles; add a story for every new variant."; echo
  done
  echo '## Code style'; echo '- Prefer named exports. Keep functions small and pure where you can.'
  echo '- Money is always integer cents; never use floating point for prices.'
} > AGENTS.md
echo '@AGENTS.md' > apps/web/CLAUDE.md
printf '# Web\n\nRoutes live in src/routes. Money is always integer cents; never use floating point for prices.\n' > apps/web/AGENTS.md
printf '# API\n\nEvery handler validates its body with zod before touching the database.\n' > apps/api/AGENTS.md
printf -- '---\npaths:\n  - "apps/web/src/**/*.test.tsx"\n---\n\n# Web tests\n\n- Query by role, not by test id.\n- Use userEvent, not fireEvent.\n- No snapshot tests for components.\n' > apps/web/.claude/rules/testing.md
printf -- '---\ndescription: Web tests\nglobs: apps/web/src/**/*.test.tsx\nalwaysApply: false\n---\n\n# Web tests\n\n- Query by role, not by test id.\n- Use userEvent, not fireEvent.\n- No snapshot tests for components.\n' > .cursor/rules/web-testing.mdc
echo 'export const Button = () => null;' > apps/web/src/Button.tsx
echo 'test("renders", () => {});' > apps/web/src/Button.test.tsx
echo 'export const server = {};' > apps/api/src/server.ts
git add -A && git -c user.email=t@example.com -c user.name=t commit -qm init
