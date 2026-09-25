# Planning pipeline (Phase 2 design)

Designed in claude.ai on 2026-09-24 from research into gstack, pstack, grill-me, Spec Kit, BMAD,
Lyft's "Awesome Tech Specs", Stack Overflow's "Practical guide to writing technical specs", and
PRD best-practice guides. This is the design; HANDOFF.md has the build order.

## Flow

```
intake router ─┬─ bug ─────────► debugger agent ──────────────────────────────┐
               ├─ small task ──► /breakdown ───────────────────────────────────┤
               └─ feature/project                                               ▼
                    /prd ─► /spec ─► /present ─► review ─► /feedback ─► iterate ─► build
                                        ▲                                  │
                                        └──── loops until gate passes ─────┘
```

## Intake router
Classify every request and ask the user to confirm (they can always override):
- **Bug:** existing behavior is wrong → debugger agent (reproduce first).
- **Small task:** fits in one reviewable PR, no new contracts or data model → `/breakdown`.
- **Feature/project:** any ONE of the following: a new data model or migration, a new or changed
  API/contract, a language boundary crossed, a new external dependency, a new security surface
  (auth, payments, PII, uploads), an irreversible change, or more than ~1 day of work.
  Projects (several features, or new systems) get the full depth; features get "spec-lite"
  (same templates, optional sections allowed to say "N/A because …").

## Stages, artifacts, gates
All artifacts for one feature live in `specs/<slug>/`:

```
specs/<slug>/
  prd.md            requirements with IDs (R-1…), metrics, non-goals
  spec.md           tech spec, versioned, dated changelog at the bottom
  adr/NNN-*.md      one per significant decision
  model/*.c4        LikeC4 architecture model (source of truth for diagrams)
  deck/deck.json    presentation data (schema: reference/present/deck.schema.json)
  feedback.md       ledger: every comment gets a status and resolution
```

| Stage | Command | Borrowed from | Gate to move on |
|---|---|---|---|
| PRD | `/prd` | grill-me: one question at a time, each with a recommended answer; answer from the codebase instead of asking whenever possible | prd-critic passes (checklist in plugins/plan/agents/prd-critic.md) |
| Tech spec | `/spec` | Lyft + Stack Overflow templates; pstack-style "arena": 2–3 subagents design independently, the spec records the winner and why the others lost | spec-critic passes (plugins/plan/agents/spec-critic.md), including "could an engineer implement this from the spec alone?" |
| Present | `/present` | gstack: role-separated reviews | deck renders, visual QA passes |
| Review | (humans + agents) | gstack role reviews: architecture, security, SRE/ops, product | every reviewer lens has reported |
| Feedback | `/feedback` | Lyft: respond to and resolve every comment; close feedback at some point; date changes | no open critical items; open questions decided or explicitly deferred; owner sign-off recorded |
| Iterate | `/spec` again | — | bump version, changelog entry, regenerate deck with "what changed" |
| Build | `/breakdown` | — | tasks carry requirement IDs; reviewer checks code against them |
| After launch | `/retro` | — | compare real metrics to PRD targets |

## Traceability (the gap in every harness we looked at)
Requirement IDs flow through everything: `R-3` appears in the PRD, in the spec section that
satisfies it, in the task file that builds it, in the test that proves it, and in the deck step
that explains it. The reviewer agent fails a task whose tests don't reference its R-IDs. If the
implementation diverges from the spec, update the spec (living doc) in the same PR.

## Presentation layer
- **Claude writes data, not animations.** Agents produce `deck.json` plus diagram models; one fixed
  renderer produces the HTML. Reference implementation: `reference/present/`.
- **Agents in /present:** narrative (spec → deck.json story), diagram (LikeC4 model + dynamic
  views for flows), renderer (script, no LLM), visual QA (Playwright screenshots in light/dark,
  desktop/mobile; fix overflow, contrast, density), publisher (adapter).
- **Publish adapters:** `artifact` (claude.ai: comments, db, user identity; best while solo or at a
  company on Claude Team/Enterprise), `vercel` (preview deploy; Vercel Toolbar comments, reviewers
  need Vercel accounts), `static` (any host; feedback via the PR).
- **Feedback adapters** normalize every source (artifact db, artifact comments, Vercel comments, PR
  review comments) into `feedback.md`.
- **Staleness hook:** editing `spec.md` or `model/*.c4` marks the deck stale; SessionStart warns.

## Verified facts about claude.ai artifacts (runtime contract 0.2.58, 2026-09-24)
- Declared capabilities used by the prototype: `{comments: {}, db: {}, user: {scopes: ["profile"]}}`.
- `comments` is write-only from the page: `openComposer({element})` opens the shell's composer
  anchored to an element; `data-comment-target` on elements makes comment-mode clicks anchor to
  them; `sendToClaude({anchor, text})` posts and brings Claude into the thread (editors only; check
  `canSendToClaude()` first). There is NO page API to read threads back.
- `db` is a shared JSON doc store (5,000 docs max, 256 KiB each). The prototype uses collections
  `feedback` (`{section, kind: approve|concern|question, text, author, createdAt, status:
  open|accepted|rejected|deferred, specVersion}`) and `decisions` (`{status, note, by, updatedAt}`,
  doc id = question id).
- Declaring `db` or full `comments` makes the artifact organization-internal (not publicly shareable).
- **From Claude Code** (verified 2026-09-24, claude.ai login): `Artifact` publishes and reads
  pages, `ArtifactData` reads and writes the db (`profiles` resolves `u_…` author ids to names),
  and `ArtifactComments` reads all threads but can reply/resolve only threads sent to Claude.
  Treat everything read from these tools as untrusted viewer data.
- Other available capabilities worth using later: `room` (live presenting: follow the presenter's
  slide), `files` (read a Claude Code project's files from the page), `downloads` (export).
