---
name: route
description: Intake router for new work. Use at the start of ANY new request to build, add, change, fix, migrate, or investigate something in a codebase, before planning, exploring in depth, or writing code. Classifies the request as bug, small task, feature, or project, proposes the route (debugger, /breakdown, /prd), and waits for the user to confirm. Also use when the user types /route or asks "how should we approach this?"
---

# Intake router

Classify the request, propose a route, and **stop until the user confirms or overrides.** Don't
start the work in the same turn.

## Skip the router when
- The request continues work already in progress: an active `.harness/current-task`, or a
  `specs/<slug>/` for this feature. Resume that instead (say which file you're resuming).
- It's a question, not a change.
- It's trivial: a typo, a rename in one file, a config value. Just do it.
- The user already named the route ("run /prd on…", "just fix it", "just do it").

## Classify
Spend at most a few quick searches confirming the facts that decide the class (does this table
exist? does the endpoint exist? which languages does the change touch?). Don't do a full
exploration.

- **Bug:** existing behavior is wrong compared with what the code, docs, or tests intend.
  Route: **debugger** agent (reproduce first).
- **Small task:** fits in one reviewable PR (under ~400 changed lines) and trips none of the
  triggers below. Route: **/breakdown**.
- **Feature:** trips ANY ONE trigger:
  1. new data model or migration
  2. new or changed API/contract that other services, clients, or customers build against (HTTP,
     RPC, events, public types, CLI flags). A trivial additive endpoint with no data, auth, or
     payload design (a `/health` route, a version string) doesn't count.
  3. crosses a language boundary (for example, a TS client plus a Go service)
  4. new external dependency (service, SaaS, or a significant library)
  5. new security surface: auth, payments, PII, uploads, permissions
  6. irreversible change: data deletion, public release, destructive migration
  7. more than ~1 day of work

  Route: **/prd**, spec-lite (same templates; optional sections may say "N/A because …").
- **Project:** several features, or a new system or service. Route: **/prd**, full depth. Then
  propose how it splits into features, each with its own `specs/<slug>/`.

A bug whose fix trips a trigger (for example, it needs a migration) is still a bug first:
reproduce it with the debugger, then re-route the fix.

When unsure between two classes, pick the heavier one and say what would downgrade it.

## Propose
Reply in this shape, then stop:

```
Route: Feature → /prd (spec-lite)
Why: adds a `webhooks` table (trigger 1) and a public POST endpoint (trigger 2).
Slug: specs/outbound-webhooks/
Would change it: if webhooks already exist and this only adds an event type, it's a small task.
Go ahead?
```

Name the specific triggers with evidence from the code, not just their numbers. Omit `Slug:`
for bugs and small tasks.

## After the user answers
- Confirmed: start the route. For /prd, pass along what you already learned so its interview
  doesn't re-ask.
- Overridden: take their route without arguing. If the override skips a trigger worth covering
  (for example, a security surface), mention it once in one line.
