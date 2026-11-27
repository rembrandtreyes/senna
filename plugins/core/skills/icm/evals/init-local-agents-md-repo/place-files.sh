#!/usr/bin/env bash
# Builds a made-up repo that keeps its agent instructions in AGENTS.md only.
set -eu
git init -q
mkdir -p packages/billing/src packages/ui/src
echo '{"name":"acme","private":true,"workspaces":["packages/*"]}' > package.json
{
  echo '# Acme'; echo; echo 'Two packages: billing (invoices, Stripe webhooks) and ui (React components).'; echo
  echo '## Commands'; echo '- `npm test -w packages/<name>`'; echo
  echo '## Billing'
  echo '- Amounts are integer cents. Never use floats for money.'
  echo '- Webhook handlers must be idempotent: store the event id before acting on it.'
  echo '- Invoice numbers come from the sequence table, never from Date.now().'
  echo '- Billing tests run against the Stripe mock in packages/billing/test/stripe-mock.ts.'
  echo; echo '## UI'
  echo '- Components are function components with props types exported next to them.'
  echo '- Style with CSS modules; no inline styles.'
  echo '- Every component has a story in the same folder.'
  echo '- Query by role in tests.'
  echo; echo '## Everyone'; echo '- Small PRs. Conventional commit messages.'
} > AGENTS.md
echo 'export const invoice = () => 0;' > packages/billing/src/invoice.ts
echo 'export const Button = () => null;' > packages/ui/src/Button.tsx
git add -A && git -c user.email=t@example.com -c user.name=t commit -qm init
