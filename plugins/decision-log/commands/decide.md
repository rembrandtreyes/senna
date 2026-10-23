---
description: Record a decision in this branch's decision log, so the PR story and later sessions keep the why
argument-hint: [the decision and its reason, or nothing to log what this conversation settled]
---

Record decisions in this branch's decision folder, `.harness/decisions/<branch>/`, writing each
`/` in the branch name as `__`. Input: $ARGUMENTS

- With input, record that decision. Without, record each decision this conversation settled
  that the folder doesn't have yet. The reason is the one the user or the conversation gave; if
  there is none, ask for it once, and write "reason not recorded" if it stays unknown.
- One new file per decision, `NNN-<slug>.md`: NNN is one past the highest number in the folder
  (`001` for the first), and the slug is a few words of the title, lowercase, with hyphens.
  There's no index to update: the SessionStart hook builds it from the files.
- Never edit an existing decision. A reversal is a new one whose `Replaces:` line gives the
  number it replaces.
- The file:
  ```
  # <what was chosen, in one short sentence>
  - Date: YYYY-MM-DD
  - Over: <the alternatives rejected>
  - Why: <the reason>
  - Files: <paths affected, or "none yet">
  - Replaces: <its number; only for a reversal>
  ```
- On a detached HEAD there's no branch folder: say so, and offer to put it in the task's Log.
- Finish with "Logged: <title>" for each decision, on one line.
