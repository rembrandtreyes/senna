# What ICM changes, measured

Three pre-registered experiments on one real team monorepo (a TypeScript/React portal), with
headless Claude Code runs (claude-opus-5-5, 2.1.319), November 2026. Scripts, prompts, and raw
results stayed outside this repo. Use these numbers to set expectations, and say they come from
one repo and one model.

## 1. Do path-scoped rules matter, and how do they reach Claude? (216 runs)
Nine portal rules (test IDs, mock paths, assertions, import aliases...) whose `paths:` were
written from the repo root, so they never loaded natively. Nine spec-writing tasks, 3 reps per arm.

| Arm | Opened a rule file before the first edit | Rule violations (27 runs) |
|---|---|---|
| A: rules dead, a loaded AGENTS.md points to them | 26/27 | 0 |
| B: rules fixed, loading natively, still pointed to | 27/27 | 0 |
| C: no rules at all | 0/27 | 34 (10 runs) |
| D: rules dead, pointers removed | 1/27 | 36 (10 runs) |

- The rules carry real information (C vs A, permutation p = 0.0003). Without them Claude copies
  whatever nearby code does, good or bad.
- A routing line in a loaded file was enough for a strong model to find and follow dead rules (A).
  Remove it and dead rules are as good as deleted (D = C, p = 0.0005). Hence the audit's rule:
  dead and routed = should, dead and unrouted = blocker.
- Native loading plus routing (B) cost about 5% more than routing alone (the rules were read
  twice). Native loading alone, without routing, wasn't measured.

## 2. Does the ICM layout and the staged workflow help real work? (90 runs)
Ten merged portal PRs, each run at its parent commit from a ticket-style prompt, graded by the
PR's own specs (hidden tests). Every task was validated: the PR's code passes them, no change fails.

| Arm | Resolved | Cost / run | Time / run | Instruction tokens loaded |
|---|---|---|---|---|
| BASE: the repo's context as it was | 30/30 | $1.22 | 185 s | ~9,400 |
| ICM: `/icm init` layout (lean root + routing, catalogs routed to reference files) | 30/30 | $1.22 | 171 s | ~8,400 |
| WF: ICM + `workflows/feature/` plan → build → verify, a session per stage | 27/30 | $2.68 | 417 s | ~8,600 |

- In a repo that's already well kept, the restructure changed neither outcomes nor cost for a
  strong model: instruction files are a small part of what a real task reads. Don't promise speed
  or quality from it. Its value is robustness (rules that load, routes that hold up),
  legibility, and smaller always-on context.
- Typecheck: new type errors appeared only in agents' own test files (runs couldn't typecheck):
  BASE 3/30 runs, ICM 1/30 (Fisher p = 0.61), WF 5/30, mostly leftover probe files.
- Exploratory, not significant: ICM runs checked their own work (tests, Biome) less often
  (18/30 vs 25/30, Fisher p = 0.08), and all 6 formatting slips came from runs that skipped
  Biome. When moving text out of the root file, keep the "how to verify a change" instructions
  there.
- The staged workflow cost 2.2x and took 2.3x as long, and it resolved fewer tasks unattended.
  The 3 failures weren't wrong code; they were no code. The plan stage surfaced decisions the
  repo says go to the engineer, and a fresh build session stopped to ask with nobody at the
  gate. Stages fit work where a person reviews between them, which is the paper's design. For
  unattended runs, have the plan stage record the decision it made instead of asking.
