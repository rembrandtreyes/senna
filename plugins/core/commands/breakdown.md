---
description: Break an idea (or an approved plan-mode plan) into task files with testable acceptance criteria
argument-hint: <what you want to build or change>
---

Break this work into tasks: $ARGUMENTS

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
