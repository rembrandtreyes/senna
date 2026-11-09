# Learn from reviews (`/icm learn`)

Rank what reviewers keep correcting by how many PRs paid for it, then check whether each rule
reaches Claude at the files where it was needed. This is the paper's "fix the source, not the
output", run on the team's own review history. On one real repo (240 PRs) it found that 62 of
100 recurring conventions were in no instruction file, 7 sat in files that never loaded where
needed, and 4 instruction lines contradicted the reviewers.

Everything here is read-only. Proposed fixes go to the user as a patch or local files.

## 1. Collect
`bash ${CLAUDE_PLUGIN_ROOT}/skills/icm/scripts/review-comments.sh <owner/repo> <count> .harness/icm/reviews.jsonl`
(merged PRs, most recent first; 150-250 PRs is about six weeks on an active repo). It writes
bodies straight to disk, so they never pass through the conversation. Where `gh` isn't available,
use the GitHub MCP tool per PR, but have a script copy results from disk, not by retyping.

Drop bot comments (`bot: true`, or names of review bots) and replies that only acknowledge.
Keep a PR-to-areas map (`git log` with `--name-only`) for the area counts.

## 2. Classify (subagents, ~300 comments each)
Give each subagent a slice of the JSONL and this brief. Have it write one JSON line per comment,
and don't paste the comments into its prompt:

> For each comment decide what it asks of the author. type: "convention" (how THIS codebase does
> things, would apply to other changes: naming, where code lives, which helper/type/pattern, test
> style, error handling, data access, API shape), "practice" (general advice), "specific" (this
> change's logic or a bug), or "noise" (question, praise, ack). For convention and practice, write
> the rule as one imperative sentence that would prevent the comment next time, using the repo's
> real names. Add topic and scope (repo-wide or a folder). Be strict: replies are usually noise.

## 3. Cluster
Count per distinct PR, not per comment: one large PR can hold 40% of the comments. Dedupe on
(PR, rule), then group rules into themes (data access, UI building, errors, enums, tests,
placement, naming...). A theme that recurs across PRs outranks a long list from one PR. Rules
seen in a single PR go on a "for the team to confirm" list, not into the fix.

## 4. Check coverage
For each distinct convention and the file it was flagged on:
`bash ${CLAUDE_PLUGIN_ROOT}/skills/icm/scripts/icm-audit.sh reach <repo> <path> --text`
prints exactly what Claude loads there. Have a subagent judge each rule:
- **reaches:** stated clearly in that text (quote the line)
- **elsewhere:** stated in an instruction file that doesn't load there (a skill counts as elsewhere)
- **missing:** in no instruction file

For reaches and elsewhere, `git log -S "<phrase>"` dates the line: added after the review means
the team already fixes at the source. Also flag instruction lines that contradict a reviewer, and
rules written only in non-instruction docs (READMEs, doc comments). Those are the cheapest fixes.

## 5. Propose
For each recurring gap, write the smallest text that would have prevented it, where it loads for
the flagged files:
- a repo-wide rule goes in the root (or a rule scoped to the language)
- a folder rule goes in that folder's `AGENTS.md` / `CLAUDE.md`
- existing docs get routed: a folder `AGENTS.md` that points to them, or a routing line

Follow the repo's conventions (AGENTS.md as the shared file, twins for other tools, its voice).
Verify with `reach` that each new line loads at the flagged files, and report what it costs at
launch (`icm-audit.sh`). Deliver a patch plus a report:
- review volume by area
- coverage counts
- the ranked gaps
- conflicts to settle
- single-PR candidates

## 6. Measure
Rerun monthly (or from `/retro`) and track the share of PRs carrying a convention comment that the
instructions already cover. To prove a fix works before rollout, run a small A/B on tasks in
folders whose code breaks the convention. That's where a rule changed Claude's output in the
first experiment (`evidence.md`).
