#!/usr/bin/env bash
# Builds a made-up repo whose Claude rules are written from the repo root.
set -eu
git init -q
mkdir -p apps/web/src apps/web/.claude/rules .cursor/rules
echo '# Storefront' > CLAUDE.md
for r in testing:'apps/web/src/**/*.test.tsx':'Query by role, not by test id.' imports:'apps/web/src/**/*.tsx':'Import from @/components, never with ../../ chains.'; do
  name="${r%%:*}"; rest="${r#*:}"; glob="${rest%%:*}"; text="${rest#*:}"
  printf -- '---\npaths:\n  - "%s"\n---\n\n# %s\n\n- %s\n' "$glob" "$name" "$text" > "apps/web/.claude/rules/$name.md"
  printf -- '---\ndescription: %s\nglobs: %s\nalwaysApply: false\n---\n\n# %s\n\n- %s\n' "$name" "$glob" "$name" "$text" > ".cursor/rules/web-$name.mdc"
done
echo 'export const Cart = () => null;' > apps/web/src/Cart.tsx
echo 'test("cart", () => {});' > apps/web/src/Cart.test.tsx
git add -A && git -c user.email=t@example.com -c user.name=t commit -qm init
