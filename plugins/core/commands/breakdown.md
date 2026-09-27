---
description: Break an idea, an approved plan-mode plan, or an approved spec (specs/<slug>) into task files with testable acceptance criteria and requirement IDs
argument-hint: <what you want to build or change | spec slug>
---

Break this work into tasks: $ARGUMENTS

**From a spec:** if the argument names a spec (a slug under `specs/`, or a `spec.md` path), the
spec is the plan. Don't re-plan it:
- If spec.md's Status isn't `approved`, say so (the review hasn't signed off) and ask whether to
  continue anyway.
- Make one or more tasks per milestone, in milestone order. Each gets `Spec:` (path and milestone)
  and `Requirements:` (that milestone's R-IDs, split across its tasks). The Requirement coverage
  table names the tests for each R-ID; turn them into acceptance criteria tagged with the R-ID.
- Accepted feedback items in `feedback.md` that the spec now addresses are already in the spec;
  don't add them again.
- Before finishing, check every R-ID in each milestone is in some task's `Requirements:` line, and
  list any that aren't.

Tip: for big or fuzzy work, think it through first in Claude Code's built-in plan mode (`/plan`),
then run this command to turn the approved plan into task files. If a plan from this session
already exists, use it as the input instead of re-planning from scratch.

1. Use the task-files skill for format and rules.
2. If the relevant code is unfamiliar, dispatch the **explorer** subagent first (several in
   parallel if the work spans areas, such as the web client and the Go service).
3. Ask me up to 3 clarifying questions **only** if the answers would change the plan. Otherwise
   state your assumptions in the task file.
4. Write the task file(s) in `tasks/`. Split work that's too big for one reviewable PR, and fill in
   `Touches:` so we can tell which tasks are safe to run in parallel worktrees.
5. Write the path of the first task to `.harness/current-task`.
6. Finish with a short summary: the tasks, their dependency order, and which can run in parallel.

Don't write implementation code in this command.
