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
Pick the cheapest layer that would catch the bug (the testing skill has the rubric).
- **Logic:** plain Vitest unit tests. Pull logic out of components to test it here.
- **Components:** Testing Library, queried by role and label, driven with `userEvent`. Anything
  that depends on layout, scrolling, focus, or real browser APIs runs in **Vitest Browser Mode**:
  jsdom has no layout, so those tests pass there while the UI is broken.
- **Network:** mock with MSW at the HTTP boundary, never by mocking the module that calls
  `fetch`. Build handler payloads from the same schema the app validates with, so they can't
  drift from the contract.
- **Database:** don't mock the client for queries or access policies (RLS); those mocks agree
  with your assumptions, not the database. Run them against a real local database, or make it
  a type error: a column list that `satisfies` the generated DB types.
- **Third-party APIs:** fixtures are recorded real responses, and requests are checked against
  the provider's actual schema rules, not a hand-written mock.
- **Runtime:** behavior specific to the edge runtime, `after()`, or streaming isn't covered by
  Node-based unit tests. Test it where it runs, or say it needs a manual check.
- **E2E (Playwright):** only the critical journeys the spec names. Make sure CI runs the existing
  ones before writing more.
- Every bug fix gets a regression test at the layer that would have caught it.

## Before finishing
The Stop hook runs `tsc --noEmit` (plus tests in parallel/auto mode). Run them yourself first if
you changed types that cross files.
