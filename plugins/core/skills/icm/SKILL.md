---
name: icm
description: Audits and sets up a repo's agent context by layer (Interpretable Context Methodology) - what loads every session, what loads per folder, path-scoped rules, and workflow stage contracts - on top of Claude Code's own loaders. Use when the user types /icm; opens, clones, or joins an unfamiliar repo or a new company's codebase; asks to audit, clean up, slim down, or organize CLAUDE.md, AGENTS.md, .claude/rules, or Cursor/Copilot rules; says Claude ignores a rule or instruction that another tool follows; says context is bloated or CLAUDE.md is too long; wants instructions for one part of a monorepo; asks what reviewers keep correcting or how to cut review comments with better agent context; or wants a repeatable multi-step workflow (release, migration, incident) written down for agents. Audit is read-only; init proposes before writing and starts local-only.
argument-hint: "[audit | learn | init | promote] [path]"
---

# ICM: context by layer

The folder structure decides what context the agent gets at each step (ICM, Van Clief and
McDermott, 2026). Here it's applied to code repos through Claude Code's own loaders, so the right
context loads because of where it lives, not because Claude remembered to read it. The best
context is the smallest set that answers the question at hand: keep things out rather than
compress them later.

## Layers in a code repo

| Layer | Answers | Lives in | Loads | Budget |
|---|---|---|---|---|
| L0+L1 identity, routing | Where am I? Where do I go? | root `CLAUDE.md` (+ `@imports`), unscoped root rules, skill descriptions | every session; re-injected after compaction | ~1,100 tok, < 200 lines |
| L2 area | What's true in this folder? | nested `CLAUDE.md` (or `AGENTS.md` + a sibling `CLAUDE.md` of `@AGENTS.md`), `paths:` rules | when Claude reads or edits a file there; gone after compaction until touched again | 200–500 tok each; whole path < ~8k |
| L2 stage | What do I do at this step? | `workflows/NN_<name>/CONTEXT.md` | when the stage runs | 200–500 tok |
| L3 reference | What rules apply? (stable) | files a contract routes to; skill references | on demand | 500–2k per stage |
| L4 working | What am I working on? (per run) | stage `output/`, `tasks/`, `specs/` | per run | varies |

Why it's shaped this way:
- **L3 and L4 stay apart.** Reference is absorbed as constraints ("write like this"); working
  material is input to transform. Mixed together, the model has to sort them itself.
- **A catalog is L3, not L2.** Per-component docs, API lists, and glossaries in an area file load
  with every edit there. Keep the contract in the area file and route to the catalog.
- **One home per rule.** The same rule in two layers loads twice in the same place and drifts.
- **Every stage output is a file** a person can read and edit before the next stage reads it.
- **Fix the source, not the output.** The same correction made three times to agent output is a
  contract or reference bug: propose the fix there, and capture it with /retro.

**What to promise** (measured on one real repo, details in `references/evidence.md`): rules that
reach Claude change what it writes, and a single routing line can carry a rule whose loading is
broken. Restructuring an already tidy repo's context didn't change pass rates or cost on real
tasks; sell it as robustness and legibility, not speed. Staged workflows cost about 2x and stall
unattended when the plan surfaces a decision, so recommend them only where a person reviews
between stages.

**Loader facts that break setups silently** (Claude Code 2.1.319; details, sources, and a probe
in `references/loaders.md`):
- A rule's `paths:` resolve from the folder that holds its `.claude/`. In
  `apps/web/.claude/rules/`, `apps/web/src/**` matches nothing; `src/**` is right.
- `@imports` load with the file that names them: no saving over pasting the text in.
- With a root `CLAUDE.md`, Claude reads no `AGENTS.md` unless a `CLAUDE.md` imports it. In a
  repo with only `AGENTS.md`, adding a `CLAUDE.local.md` switches `AGENTS.md` off for you.
- On-demand files (nested `CLAUDE.md` plus imports, scoped or nested rules) are cut off past
  ~40,000 characters. Invalid YAML in a rule's frontmatter makes it load everywhere.

## audit (default; read-only)
1. **Measure.** Run `bash ${CLAUDE_PLUGIN_ROOT}/skills/icm/scripts/icm-audit.sh <repo-root>` (it's
   `scripts/icm-audit.sh` in this skill's folder). It prints launch and per-folder costs, the
   largest sections, and ranked findings. Use its numbers instead of recounting.
2. **Read the repo's own rules about instruction files** first (a section in `AGENTS.md` or
   `CLAUDE.md`, CONTRIBUTING, a tooling doc). Audit against them: duplication the repo documents
   on purpose (rule twins for another tool) isn't a finding, and anything that cuts across their
   convention is an option for the team, not a defect.
3. **Confirm the blockers.** Each is a lead with evidence. When a claim rests on loader behavior
   (a rule or file that never loads) and the `claude` CLI is available, prove it once with the
   probe in `references/loaders.md`, in a scratch copy, never in the audited repo (its hooks
   would run). Say what you verified and on which version.
4. **Judge what the script can't:**
   - Wrong layer: catalogs in area files; another tool's setup notes in shared L0; one folder's
     advice in the root; rules that matter only when editing instruction files (a scoped rule on
     `**/AGENTS.md`, `**/CLAUDE.md`, `**/.claude/rules/**`).
   - The same rule in different words in two places that load together.
   - Contracts doing two jobs, or too vague to act on.
   - Workflows whose steps pass results through the conversation (a review report the next skill
     needs): lost at compaction, and nobody can edit it in between. Each step should write a file.
   - `reverify` lines: check each claim against the repo ("until X lands": has it?).
   - Unrouted docs agents would need: one routing line in L0/L1.
   Leave wording for older models, contradictions, and dead command references to
   `/doctor prompt-audit`; mention it instead of repeating it.
5. **Report.** Write `.harness/icm/audit-<YYYY-MM-DD>.md` from `references/report-template.md`
   (create `.harness/` with a `.gitignore` of `*` if it's missing). Tell the user the counts, each
   blocker with its evidence and fix, and the top should-fixes. Ask before changing anything.

Severity: **blocker**, an instruction that reaches Claude by no route (it doesn't load and nothing
points to it), arrives truncated, or a stage input that doesn't exist. **should**, it loads but
costs too much, loads twice, or sits in the wrong layer, or it doesn't load but a loaded file
points to it (it works until someone edits that pointer). **consider**, structure and upkeep.
**info**, facts to check.

## learn (from the team's review comments)
The highest-return fix in a repo with decent context: rank the conventions reviewers keep asking
for by distinct PRs, check with `icm-audit.sh reach <repo> <path>` whether each reaches Claude at
the files where it was flagged, and propose the smallest instruction text that closes each
recurring gap. Read-only; deliver a patch and a report. Steps and prompts:
`references/review-mining.md`.

## init (propose, then write locally)
For a repo with little context, or to apply audit findings.
1. **Discover.** Run the audit. If `architecture/*.c4` exists, take the areas and their code
   links from it (the architecture skill). Otherwise map areas from the workspace or build graph
   (npm/pnpm workspaces, nx, turbo, `go.work`, Cargo workspace) and top-level folders. Explore
   before asking; ask only what the code can't answer, one question at a time with a recommended
   answer: what matters most, what keeps going wrong, which multi-step workflows repeat.
2. **Propose, write nothing yet.** Show the tree with layer tags. For each file: what goes in,
   where it comes from (`file:line` for moved text), and launch and heaviest-area cost before and
   after. Text is moved, never dropped. Follow the repo's conventions (`AGENTS.md` as the shared
   file, twins for other tools). Wait for approval; the user can approve parts.
3. **Write local-only** unless the user picks direct mode (fine in their own repos):
   - New files go at their final paths and into a marked block in
     `$(git rev-parse --git-common-dir)/info/exclude` (shared by all worktrees):
     `# icm local (senna): /icm promote removes these`, then one `/path` per line. Append it with
     one Bash `printf >>` (the Write and Edit tools ask before touching `.git/`). Never edit
     `.gitignore` for this: it's a committed change, and many repos forbid it.
   - Committed files stay untouched. Root additions go in `CLAUDE.local.md`, a folder's in that
     folder's `CLAUDE.local.md`, scoped rules in `.claude/rules/icm/`.
   - In a repo that relies on `AGENTS.md`, start every `CLAUDE.local.md` with `@AGENTS.md`
     (that folder's), or Claude stops reading `AGENTS.md` there.
   - Moves out of committed files wait for promote; list them.
   - Keep the root's "how to verify a change" instructions (test, lint, format commands) in the
     root: runs checked their own work less often when they were further away.
4. **Validate.** Rerun the audit and show launch and area costs before and after. Probe new scoped
   rules once.
5. **Record** every added or moved piece, from → to, in `.harness/icm/moves-<YYYY-MM-DD>.md`.

## promote (local → a change the team reviews)
1. Read the exclude block and the moves file; confirm with the user which pieces go.
2. Give each piece its committed home under the repo's convention: root text into `CLAUDE.md`,
   or into `AGENTS.md` when that's the shared file (Claude-only text under the `@AGENTS.md`
   import); rules into `.claude/rules/` with the repo's naming, plus twins if the repo keeps them.
3. On a new branch from the repo's main branch, write them, apply the pending moves, and remove
   the promoted lines from the exclude block.
4. Rerun the audit and show the diff and the costs before and after.
5. Follow the repo's git rules. Many team repos say the engineer owns commits and PRs: then stop
   with the tree ready. Otherwise commit on the branch, and push only when asked.

## Workflow stages
Only for a real repeatable multi-step process (release, migration, incident, backfill), never as
decoration. One folder per stage, `workflows/NN_<name>/`, numbered in run order, with a
`CONTEXT.md` from `references/stage-contract.md` and an `output/` folder.
- One stage, one job. A person can edit `output/` before the next stage reads it.
- Run a stage with only its contract and its Inputs, stable reference first, then working
  material, then the task. A subagent sees none of the conversation: put the contract and inputs
  in its prompt.
- Stamp each output's first line with `<!-- icm-inputs: <hash> -->` from
  `icm-audit.sh stamp <CONTEXT.md>`; the audit then flags outputs whose inputs changed, so only
  that stage and the ones after it re-run.
- Run a stage's `## Verify` list as a critic subagent before the human gate.
- If stages will run with nobody at the gates, tell the plan stage to decide and record its
  decisions instead of asking, or the build stage stops and waits.
