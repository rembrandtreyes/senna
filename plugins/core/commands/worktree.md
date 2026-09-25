---
description: Spin up parallel worktrees for independent tasks
argument-hint: <task ids or branch names>
---

Create parallel worktrees for: $ARGUMENTS

1. For each task, read its task file and check that `Touches:` doesn't overlap another task in
   this batch. Warn me about any overlap before creating anything.
2. For each one, run the harness `worktree.sh <branch>` script. Its path is shown in the session's
   harness context under "Harness scripts dir". Name branches `<type>/<task-id>-<slug>`.
3. In each new worktree, write the task path to `.harness/current-task`.
4. Print a table of task, worktree path, branch, ports, and the command to start a session there.

Don't start implementing the tasks here.
