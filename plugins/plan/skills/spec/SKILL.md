---
name: spec
description: Write or revise a tech spec at specs/<slug>/spec.md from an approved PRD. Runs 2-3 designer subagents in parallel on the core design, records the winner and the rejected alternatives, writes ADRs, and gates on the spec-critic agent. Use after /prd is approved, when the user asks for a tech spec, design doc, or "how should we build this", or to revise spec.md after review feedback. Don't use it for small tasks (those go to /breakdown).
argument-hint: <slug>
---

# /spec

Input: $ARGUMENTS (a slug under `specs/`; if missing, use the only one, or ask).

Files in this skill's directory: `template.md` (the spec) and `adr-template.md`. Output goes to
`specs/<slug>/spec.md` and `specs/<slug>/adr/NNN-<decision>.md`. If `spec.md` already exists,
you are **revising**: see the end of this file.

## 0. Preconditions
- Read `prd.md`. If its Status isn't `approved`, say so and ask whether to continue anyway.
- Depth comes from the PRD (`project` or `spec-lite`).
- List the PRD's open questions. Ask the user to decide any that block the design (one at a time,
  with a recommendation, as in /prd). Carry the rest into the spec's Open questions.

## 1. Map the current system
Dispatch the **explorer** agent (several in parallel if the feature spans areas). You need the
components, data, and flows this feature touches, with file:line, for the Background section and
for the designers. Designers get this map; they shouldn't each re-explore.

## 2. Design round (the arena)
Dispatch **designer** agents **in parallel, in one message**: 2 for spec-lite, 3 for a project.
Give each the PRD path, the explorer map, and a different **stance** so the designs actually
differ. Pick stances that fit the problem. The defaults are:
- **minimal:** the least new machinery that meets every R-ID; reuse what exists.
- **robust:** optimize for failure handling, scale headroom, and operability.
- **different-shape** (projects only): a structurally different approach (for example, push vs.
  pull, sync vs. async, build vs. buy).

Designers work independently. Never show one designer another's output.

Then judge the designs yourself and show the user a scoreboard:

```
                 minimal    robust     different-shape
R-ID coverage    10/10      10/10      9/10 (misses R-8)
New components   1          3          2 + vendor
Effort           ~3 days    ~6 days    ~4 days
Reversibility    easy       medium     hard (vendor lock-in)
Biggest risk     …          …          …
Recommendation:  minimal, plus robust's retry schedule.
Why: …
```

Wait for the user to pick. A hybrid is fine: name what came from where. The winner becomes
Proposed design; each loser becomes an entry in Alternatives considered with the specific reason
it lost (not "more complex").

## 3. Write
- Fill `spec.md` from the template. Fill the **Requirement coverage** table for every R-ID in the
  PRD: design section, test(s), milestone. An R-ID you can't place means the design is missing
  something; fix the design, don't leave the row blank.
- Cite R-IDs inline in the sections that satisfy them (`Satisfies R-3, R-5.`).
- Every flow in Key flows lists its failure paths.
- Milestones are ordered, each independently shippable, each listing the R-IDs it delivers.
  `/breakdown` turns each milestone into tasks later.
- In spec-lite, these sections may say "N/A because <reason>": Data model and migrations, APIs and
  contracts, Performance and scale, Fallback plan, Cost. No other section may.
- If the ops plugin's api-contracts skill is available, use it for the contract section.

## 4. ADRs
Write `adr/001-<core-design>.md` for the design-round decision, from `adr-template.md`. Add one
more ADR per decision that is expensive to reverse or that a reviewer is likely to question
(storage engine, queue, a new dependency, a consistency model). Don't write ADRs for routine
choices. Link each ADR from the spec section it affects.

## 5. Gate: spec-critic
Run the **spec-critic** agent with the spec path and the depth. On FAIL, fix and re-run; ask the
user only for facts you don't have. After 3 failed rounds, stop and show the remaining failures.

On PASS: set `Status: in review`, give the user a short summary (the ask, the chosen design in
two sentences, milestones with their R-IDs, open questions), and suggest `/present` next.

## Revising after feedback
Bump `Version`, add a dated changelog entry that summarizes what changed and why and cites the
feedback IDs from `feedback.md` (for example, `F-7`). If a change reverses an ADR, set that ADR to
`Superseded by NNN` and write the new one; never edit an accepted ADR's decision. Update the
coverage table, re-run the critic, and tell the user the deck is stale until `/present` runs.
