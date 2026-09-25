---
name: prd
description: Write or revise a PRD (product requirements doc) at specs/<slug>/prd.md through a one-question-at-a-time interview, then gate it with the prd-critic agent. Use when the route skill sends a feature or project to /prd, when the user asks for a PRD, requirements, or "let's scope this", or when an existing prd.md needs changes. Don't use it for bugs or small tasks.
argument-hint: <feature idea or slug>
---

# /prd

Input: $ARGUMENTS (plus anything the route skill already learned; don't re-ask it).

The template is `template.md` in this skill's directory. Write the result to
`specs/<slug>/prd.md` in the project. Use the slug the router proposed, or derive a short
kebab-case one. If `prd.md` already exists, you are **revising**: see the end of this file.

## 1. Research before asking
Dispatch the **explorer** agent (from core) on the areas the feature touches. Anything the code
can answer (existing models, endpoints, limits, current behavior, dependencies) goes straight
into the draft marked **verified** with file:line. Never ask the user what the code can tell you.

## 2. Interview: one question at a time
- Ask **one** question per message, each with your **recommended answer** and a one-line reason,
  so the user can reply "yes" to move fast:
  ```
  Q4/≈9 · Unhappy paths
  What should happen when a customer's endpoint is down?
  Recommended: retry with backoff for 24h, then disable the endpoint and email the owner.
  (Matches how the existing email jobs retry, jobs/mailer.ts:40.)
  ```
- Ask in template order: Problem → Users → Metrics → Requirements → Non-goals → Unhappy
  paths → Dependencies → Risks. Ask only about gaps; skip what research already answered.
- Problem first, and keep solution talk out of it. If the user answers with a solution, ask what
  goes wrong for whom without it.
- Push for numbers: baselines, targets, limits ("p95 < 500 ms", not "fast"). If the user doesn't
  know a baseline, record how to measure it and mark it unverified. Don't invent one.
- For a solo owner, "me" is a valid owner, and the owner's own observation is valid evidence
  (mark it as such).
- The user can say "use your recommendations for the rest". Then fill the remaining sections
  with your recommended answers, flag each as an assumption, and move on.
- **Write the draft file after the first few answers and update it as you go**, so the interview
  survives compaction or a new session. Resume from the draft if one exists.

## 3. Write
Fill every section. Requirements get sequential IDs (`R-1`, `R-2`, …) that never get reused or
renumbered, because later stages cite them. Each gets a Given/When/Then acceptance check.

Depth comes from the route:
- **Project:** every section in full.
- **Feature (spec-lite):** Users, Success metrics, Non-functional requirements, Dependencies, and
  Risks may say "N/A because <reason>". Problem, Requirements, Non-goals, and Unhappy paths never
  may.

## 4. Gate: prd-critic
Run the **prd-critic** agent on the file (tell it the depth: project or spec-lite). On FAIL:
fix what you can from what you already know, ask the user (one question at a time) only for
missing facts, and re-run. After 3 failed rounds, stop and show the user the remaining failures.

On PASS: set `Status: in review`, show the user a short summary (problem, R-IDs in one line
each, non-goals, open questions), and ask them to approve. On approval set `Status: approved`
and suggest `/spec`. The critic passing is not approval; only the user approves.

## Revising an existing PRD
Bump `Version` (v1 → v2), add a dated changelog line that names the R-IDs you added, changed, or
removed, and keep removed requirements as `~~R-4~~ removed: <why>` so their IDs stay taken. If
`spec.md` exists, tell the user which spec sections cite the changed R-IDs. Re-run the critic.
