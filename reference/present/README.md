# Presentation reference kit

The working prototype from claude.ai, split into a reusable template and its data.
Live example: https://claude.ai/artifact/FZzEbydpqj2QVX4LLD8QLp

- `review-deck.template.html`: the renderer (layout, animations, review panel, capability code).
  Contains `__DECK_DATA__` and `__DECK_TITLE__` placeholders.
- `example-deck.json`: the rate-limiting example deck data.
- `deck.schema.json`: the data contract the narrative and diagram agents must produce.
- `render.mjs`: injects a deck into the template (`node render.mjs example-deck.json out.html`).

Known limitations (tracked in HANDOFF.md, Phase 2):
- Diagram node positions are hand-placed; they should come from the LikeC4 model.
- Edge ids use single-letter node initials (`l-r`), so node ids must have unique first letters.
  Replace with explicit `from`/`to` fields when generalizing.
- Section list is fixed to 8 sections; make it data-driven so spec-lite decks can skip sections.
- No "what changed since last version" view yet.
- No export button; add one (downloads capability) so feedback can reach Claude Code even if it
  can't read artifact storage directly.
