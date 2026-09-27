---
name: publish
description: Publish a spec's review deck (specs/<slug>/deck/index.html) to reviewers through an adapter - artifact (claude.ai, feedback in the deck), static (committed file, feedback through the PR), or vercel (preview deployment, Toolbar comments). Use after /present builds a clean deck, when the user asks to share, send out, or publish a deck or spec for review, or to republish after a revision.
argument-hint: <slug> [artifact | static | vercel]
---

# /publish

Input: $ARGUMENTS (a slug under `specs/`, and optionally the adapter).

Adapters are in `${CLAUDE_PLUGIN_ROOT}/adapters/<name>.md`. Each has three parts: Publish,
Collect (used by /feedback), and Write back. Read only the one you use.

## 0. Preconditions
- `deck/index.html` exists. If `deck/build-info.json`'s `specHash` differs from
  `git hash-object specs/<slug>/spec.md`, the deck is stale: say so and offer `/present` first.
- If the deck hasn't passed visual QA (the /present report said ISSUES REMAIN), say so.

## 1. Choose the adapter
Use the one named in the arguments, else the one in `deck/publish.json` (republishing keeps the
same place, so reviewers keep their link and their feedback), else ask:
- **artifact** (recommended when the Artifact tool is available and reviewers are in the owner's
  claude.ai organization): feedback, decisions, and comments live in the deck.
- **static** (works everywhere): the file is committed with the spec and feedback comes through
  the PR.
- **vercel**: when reviewers already review Vercel previews.
Check the adapter's "Available when" line before using it; if it fails, say why and offer static.

## 2. Publish
Follow the adapter's Publish section. Anything that other people will see (a PR description, a
reply, a deployment) is shown to the user and confirmed first, unless they already said to go
ahead in this request.

## 3. Record
Write `deck/publish.json` (commit it with the spec, so /feedback knows where to look):
```json
{ "adapter": "artifact", "url": "<where reviewers open it>", "specVersion": "v2",
  "specHash": "<git hash-object spec.md>", "publishedAt": "<ISO time>", "pr": 123 }
```
`pr` only for static (or whenever there's a PR); keep earlier fields the adapter needs (for
vercel, `project`).

## 4. Report
The link or path, who can open it, how reviewers give feedback, and the date feedback closes
(from spec.md's header; ask the user if it's empty and fill it in). Then: "Run `/feedback <slug>`
to pull feedback into `feedback.md`."
