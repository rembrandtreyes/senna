---
name: task-files
description: Format and rules for task files in tasks/, the unit of work for planning, parallel worktrees, review, and shipping. Use whenever planning work, creating or splitting tasks, updating task status, deciding what can run in parallel, or whenever a task ID (like T-012) or a file in tasks/ is mentioned.
---

# Task files

One task is one reviewable PR (aim for under ~400 changed lines). Task files live in `tasks/`,
named `T-<number>-<slug>.md`. `.harness/current-task` holds the path of the active one.

## Template

```markdown
# T-012: Add rate limiting to the public API

Status: todo            # todo | in-progress | review | done | blocked
Depends on: T-010       # or "none"
Touches: services/api/middleware/*, services/api/config.go
Stack: go

## Goal
One or two sentences: the user-visible outcome, not the implementation.

## Context
Why now, links, constraints, and assumptions made during planning.

## Acceptance criteria
- [ ] Observable and testable: "Requests over 100/min per key get 429 with Retry-After"
- [ ] Each criterion maps to at least one test

## Out of scope
- Things a reasonable person might assume are included but aren't

## Verification
`go test ./services/api/...` plus a manual check: `curl ... | grep 429`

## Log
- 2026-09-24 created
```

## Rules
- **Acceptance criteria are the contract.** The reviewer agent grades against them, so write
  them to be checkable by someone who didn't write the code.
- **`Touches:` predicts conflicts.** Two tasks with overlapping `Touches:` shouldn't run in
  parallel worktrees.
- **Cross-stack changes** (for example, a TS client plus a Go service) either get one task per side
  with a contract task first, or one task that lists both stacks. See the api-contracts skill if
  it's installed.
- **Update as you go.** Set `Status: in-progress` when starting, append to `Log` at milestones, and
  set `Status: review` in /ship. Anything learned that changes the plan goes in `Context`.
- If a task balloons, stop and split it. Don't silently expand scope.
