---
name: react-next
description: Conventions and workflow for React and Next.js (App Router) code in this harness. Use whenever writing, reviewing, or debugging React components, hooks, Next.js routes, server actions, data fetching, or TypeScript in a web project, even for small edits.
---

# React / Next.js conventions

These are starting defaults. Edit them to match how you actually like to work, and let /retro
promote real lessons into here.

## TypeScript
- `strict` mode. No `any`. Use `unknown` plus narrowing at boundaries.
- Validate all external input (request bodies, search params, env, third-party responses) at the
  boundary with a schema (zod or the project's choice), and infer types from the schema.
- Prefer discriminated unions over boolean flag soup for state.

## Next.js (App Router)
- Server Components by default. Put `'use client'` at the **leaves** that need interactivity,
  not at the top of a tree.
- Fetch data on the server. Don't fetch in `useEffect` when a Server Component or route handler
  can do it.
- Mutations go through server actions or route handlers, and are validated there. Never trust the
  client.
- Keep secrets server-only. Only `NEXT_PUBLIC_*` reaches the browser, so never put secrets there.
- In a parallel worktree, the dev server port comes from `PORT` in `.harness/ports.env`.

## React
- Derive state instead of syncing it. Most `useEffect`s that set state are bugs waiting to happen.
- Colocate: component, styles, and test live side by side.
- Accessibility is part of done: semantic elements, labels, keyboard access, and focus handling in
  dialogs.

## Tests
- Test behavior through the UI (Testing Library queries by role/label), not implementation details.
- Every bug fix gets a regression test.

## Before finishing
The Stop hook runs `tsc --noEmit` (plus tests in parallel/auto mode). Run them yourself first if
you changed types that cross files.
