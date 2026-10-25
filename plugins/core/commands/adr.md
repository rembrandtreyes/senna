---
description: Record a standing decision in docs/adr/ - a project-wide rule for how code is written, which every session sees and the reviewer checks each change against
argument-hint: [the decision and its reason, or nothing to record what this conversation settled]
---

Record a decision record in `docs/adr/`. Input: $ARGUMENTS

- These are standing rules for the whole project: structure, patterns, libraries, boundaries.
  A choice made for one branch goes in its decision log (`/decide`) or the task's Log instead,
  and a design decision for one spec goes in `specs/<slug>/adr/`.
- The reason is the one the user or the conversation gave. If there is none, ask once, and
  write "reason not recorded" if it stays unknown. Never invent one.
- `Check:` says what a reviewer would see in a diff that breaks the rule. If no diff could show
  that, it isn't a record: suggest a line in the project's CLAUDE.md instead.
- The file is `docs/adr/NNN-<slug>.md`: NNN is one past the highest number there (`001` for the
  first), and the slug is a few words of the title, lowercase, with hyphens.
  ```
  # ADR-NNN: <the decision, in a few words>

  Status: accepted   ·   Date: YYYY-MM-DD   ·   Replaces: ADR-NNN (only when it does)
  Applies to: <path patterns, e.g. src/api/**, **/*.tsx; leave the line out for all code>
  Check: <what a reviewer would see in a diff that breaks it>

  ## Context
  The problem and the forces at play, in a short paragraph or two.

  ## Decision
  We will ...

  ## Alternatives
  - **<option>:** why it lost.

  ## Consequences
  What gets easier, what gets harder, and what it would cost to reverse.
  ```
- `Status:` is `accepted` once the user has settled it, and `proposed` while it still needs
  someone else's agreement; the reviewer enforces only accepted ones.
- To change a rule, write a new record with `Replaces: ADR-NNN`, and set the old one's status
  to `superseded by ADR-<new>`. That status is the only edit an accepted record ever gets.
- Don't commit it; it goes in with the change it belongs to. Finish with "Recorded: ADR-NNN
  <title>".
