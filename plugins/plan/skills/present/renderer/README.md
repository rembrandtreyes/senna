# Review deck renderer

The fixed page for `/present`. Agents write data; these files turn it into a deck.
Original prototype: https://claude.ai/artifact/FZzEbydpqj2QVX4LLD8QLp

- `review-deck.template.html`: layout, animations, review panel, capability code. Contains
  `__DECK_DATA__` and `__DECK_TITLE__` placeholders.
- `deck.schema.json`: the data contract for `deck.json`.
- `build.mjs`: `node build.mjs <deck-dir>` merges `narrative.json` (deck-narrator) and
  `diagram.src.json` (deck-diagrammer), lays out the grid diagram, validates against the schema
  and cross-references (scenario hops are edges, refs are R-IDs), and writes `deck.json` +
  `index.html`. `node build.mjs <deck.json> <out.html>` renders an already complete deck.
  No dependencies.
- `qa.mjs`: `node qa.mjs <index.html> <out-dir>` screenshots every section in light/dark at
  1440px and 390px and checks page overflow, off-screen and clipped text, diagram labels, WCAG
  contrast, density, and JS errors. Needs `playwright-core` in `~/.cache/my-harness/present`
  and Chrome or Chromium.
- `example-deck.json`: the rate-limiting example (`node build.mjs example-deck.json out.html`).

Known limitations (HANDOFF.md, Phase 2 step 7):
- Section list is fixed to 8 sections; make it data-driven so spec-lite decks can skip sections.
- The flows section's token-bucket meter only suits the rate-limit example. It's hidden unless
  a scenario step has a `bucket` value; a general "state" panel would replace it.
- Scenario tones are `allow` / `throttle` / `reject`; deck-diagrammer maps them to success /
  degraded / failed.
- No "what changed since last version" view yet.
- No export button (downloads capability) for sending feedback to Claude Code from a deck that
  isn't published as a claude.ai artifact.
- Diagram layout is a simple grid; LikeC4 may replace it (step 8).
