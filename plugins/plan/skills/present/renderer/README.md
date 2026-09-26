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

Deck data features (step 7):
- `sections`: order, relabel (`{id, nav, title}`), or leave out sections; sections with no data
  are skipped, so spec-lite decks can omit alternatives, risks, and so on.
- `changes`: a "What changed since vN" section plus "changed" markers in the nav, citing `F-n`
  feedback IDs.
- Scenario state panel: `stateLabel` on a scenario, `state` / `meter` on steps (replaces the
  rate-limit example's token bucket).
- Export feedback (JSON) in the review panel: uses the `downloads` capability when published as
  a claude.ai artifact, a plain browser download otherwise. Format `review-deck-feedback/1`,
  with author display names resolved at export time.

Known limitations:
- Scenario tones are `allow` / `throttle` / `reject`; deck-diagrammer maps them to success /
  degraded / failed.
- A selected risk card sticks out ~10px on the right at some widths.
- Diagram layout is a simple grid; LikeC4 may replace it (step 8).
