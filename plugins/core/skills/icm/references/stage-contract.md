# Stage contract template

One file per stage: `workflows/NN_<name>/CONTEXT.md`. The audit parses `## Inputs` and
`## Outputs`: a list item's first backticked path is the file, relative to the stage folder;
`path#Heading` names one section (matched against the heading text, case-insensitive).

```markdown
# Stage 02: draft the migration

One job, in a sentence: turn the approved plan into migration files and a rollback.

## Inputs
- L4 `../01_plan/output/plan.md`
- L3 `../../docs/context/db-conventions.md#Migrations`
- L3 `../../docs/context/db-conventions.md#Rollbacks`

## Process
1. ...
2. ...
Stop and ask when: <the decisions this stage must not make alone>.

## Outputs
- `output/migration-notes.md`: what changed, in plan order, each item citing its plan step
- `output/rollback.md`

## Verify
- Every plan step appears in migration-notes.md, in order (against stage 01's output).
- Each migration has a rollback entry.
```

Rules of thumb:
- **Inputs:** L3 for stable rules (absorb them), L4 for this run's material (transform it). Name
  sections instead of whole files when only part applies. Nothing the stage doesn't use.
- **Process:** what to do and when to stop. Instructions that apply to every stage belong in L0,
  not copied into each contract.
- **Outputs:** files in this stage's `output/`, written for the next stage and for the person at
  the gate. Item IDs or section names that trace back to inputs make misalignments findable.
- **Stamp:** first line of each output, `<!-- icm-inputs: <hash> -->`, hash from
  `icm-audit.sh stamp workflows/NN_<name>/CONTEXT.md` at the time the stage ran.
- **Verify:** checks of this output against earlier outputs (stage n against n-1 or n-2), run as
  a critic subagent before the person reviews.
- **Gates:** people edit the first stage's output (direction) and the last (alignment) most.
  Middle stages with clear inputs on both sides rarely need a stop.
