---
description: Record a decision in this branch's decision log, so the PR story and later sessions keep the why
argument-hint: [the decision and its reason, or nothing to log what this conversation settled]
---

Record decisions in this branch's log, `.harness/decisions/<branch>.md`, writing each `/` in the
branch name as `__`. Input: $ARGUMENTS

- With input, record that decision. Without, record each decision this conversation settled
  that the log doesn't have yet. The reason is the one the user or the conversation gave; if
  there is none, ask for it once, and write "reason not recorded" if it stays unknown.
- Create the file with `# Decisions: <branch>` as its first line (the SessionStart hook reads it
  to archive the log once the branch is deleted). Append; don't edit old entries. A reversal is
  a new entry that names the one it replaces.
- One entry per decision:
  ```
  ## YYYY-MM-DD: <what was chosen, in one short sentence>
  - Over: <the alternatives rejected>
  - Why: <the reason>
  - Files: <paths affected, or "none yet">
  ```
- On a detached HEAD there's no branch log: say so, and offer to put it in the task's Log.
- Finish with "Logged: <title>" for each entry, on one line.
