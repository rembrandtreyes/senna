---
name: present
description: Build an interactive review deck (specs/<slug>/deck/index.html) from a tech spec - narrative and diagram agents write the data, a fixed renderer builds the page, and a visual-qa agent screenshots it in light/dark at desktop and phone widths and fixes it until clean. Use after /spec passes its critic, after a spec revision (the deck is then stale), or when the user asks to present, demo, or walk reviewers through a spec.
argument-hint: <slug>
---

# /present

Input: $ARGUMENTS (a slug under `specs/`; if missing, use the only one, or ask).

`renderer/` in this skill's directory holds the fixed page (`review-deck.template.html`), the
data contract (`deck.schema.json`), `build.mjs`, `qa.mjs`, and `example-deck.json`. Claude
writes data; the renderer makes the page. Never hand-edit a generated `index.html` or the
template to fix one deck.

## 0. Preconditions
- `specs/<slug>/spec.md` exists. If its Status is `draft` (the critic hasn't passed), say so and
  ask whether to continue anyway.
- `node --version` is 18 or later.
- QA needs `playwright-core` in `~/.cache/my-harness/present` (about 13 MB, one time) and Google
  Chrome or Chromium. If `node <renderer>/qa.mjs` exits 3, ask the user before running
  `npm install --prefix ~/.cache/my-harness/present playwright-core`. If they decline, build
  without QA and say that it wasn't checked.

## 1. Write the data (in parallel)
Dispatch **deck-narrator** and **deck-diagrammer** in one message. Give both the spec path, the
PRD path, the renderer directory, and their output path: `specs/<slug>/deck/narrative.json` and
`specs/<slug>/deck/diagram.src.json`.

## 2. Build
`node <renderer>/build.mjs specs/<slug>/deck`. It lays out the diagram, merges both files into
`deck.json`, validates against the schema (including that every scenario hop is an edge and
every `ref` is a PRD R-ID), and writes `index.html`. On exit 2, fix the listed problems in the
source JSON and re-run. Warnings about long labels go to visual-qa.

## 3. Visual QA
Dispatch **visual-qa** with the deck directory and the renderer directory. It loops
build → `qa.mjs` → screenshots → fixes, at most 3 rounds, and reports CLEAN or what remains.
Template bugs it reports are real bugs in `renderer/`: tell the user and don't work around them.

## 4. Record and report
- Write `specs/<slug>/deck/build-info.json`: `{ "specVersion": "<from spec header>",
  "specHash": "<git hash-object spec.md>", "builtAt": "<ISO time>" }`. The staleness check
  compares the spec against this.
- `deck/qa/` holds screenshots; it shouldn't be committed (see the gitignore snippet).
- Tell the user the path to `index.html` (on macOS, offer `open <path>`), the QA result, and
  that feedback typed into an unpublished deck stays in that browser. Publishing to reviewers
  comes from the publish adapters.
