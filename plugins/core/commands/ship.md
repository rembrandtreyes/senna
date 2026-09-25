---
description: Verify, review, and open a PR for the current task
argument-hint: [optional notes for the PR]
---

Ship the current task (`.harness/current-task`). Notes: $ARGUMENTS

1. Run the full checks for every stack this change touches (tests, typecheck, lint). Fix any
   failures first.
2. Dispatch in parallel: the **reviewer** subagent and, if available, the **security-auditor**
   subagent. Fix every blocker they report and re-run the checks. Summarize "should fix" items
   and ask me whether to address them now.
3. Update the task file: tick the acceptance criteria, set `Status: review`, and add a log line.
4. Commit with a conventional commit message (`feat:`, `fix:`, `refactor:`...) that references the
   task ID.
5. In **interactive** mode, show me the branch and the PR description and wait for my OK before
   pushing. In **auto** mode, push the feature branch and open the PR (`gh pr create`) with
   what changed, why, how it was verified, and the task link.
6. Never push to a protected branch. The harness blocks it anyway.
