---
description: Verify, review, and open a PR for the current task
argument-hint: [optional notes for the PR]
---

Ship the current task (`.harness/current-task`). Notes: $ARGUMENTS

1. Run the full checks for every stack this change touches (tests, typecheck, lint). Fix any
   failures first.
2. Dispatch in parallel: the **reviewer** subagent (give it the harness scripts dir from the
   session context, for `rid-check.sh`) and, if available, the **security-auditor** subagent. Fix every blocker they report and re-run the checks. Summarize "should fix" items
   and ask me whether to address them now.
3. Update the task file: tick the acceptance criteria, set `Status: review`, and add a log line.
4. Commit with a conventional commit message (`feat:`, `fix:`, `refactor:`...) that references the
   task ID.
5. Push and open the PR (`gh pr create`) with what changed, why, how it was verified, and the
   task link.
   - **Interactive:** show me the branch and the PR description, and wait for my OK first.
   - **Parallel or auto:** push the feature branch (`git push -u origin HEAD`) and open the PR
     without asking. If the push or `gh` is refused (permissions, no remote, not signed in),
     stop and report the branch and the PR description instead of working around it.
6. Never push to a protected branch (main, master, production, release, or
   `HARNESS_PROTECTED_BRANCHES`). In parallel and auto modes the guard blocks it and any force
   push; in interactive mode it only blocks force pushes, so the rule is yours to keep.
