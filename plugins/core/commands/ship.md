---
description: Verify, review, and open a PR for the current task
argument-hint: [optional notes for the PR]
---

Ship the current task (`.harness/current-task`). Notes: $ARGUMENTS

1. Run the full checks for every stack this change touches (tests, typecheck, lint). Fix any
   failures first.
2. Commit with a conventional commit message (`feat:`, `fix:`, `refactor:`...) that references
   the task ID. If the branch has a decision folder (`.harness/decisions/<branch>/`, `/` as
   `__`, a file per decision), end the message with a `Decision: <chosen> over <alternatives>:
   <why>` trailer for each decision there that no earlier commit on the branch carries and no
   other decision replaces (its `Replaces:` line), so the why outlives the folder. Pass the message through a quoted heredoc (`git commit -F - <<'EOF'`)
   so backticks and `$` stay literal. Every commit below follows the same rule.
3. Write the PR description: what changed, why, how it was verified, and the task link. If the
   `pr-story` skill is listed, invoke it in author mode to write it instead, with this run's
   checks on its Verified line.
4. Dispatch in parallel: the **reviewer** subagent (give it the harness scripts dir from the
   session context, for `rid-check.sh`, and the description, whose claims it checks against the
   code) and, if available, the **security-auditor** subagent. Fix every blocker: a claim the
   code contradicts is corrected in the description, unless the task needs what it says. Re-run
   the checks, commit the fixes, update the description, and send both back to the reviewer
   until it reports no blockers. Summarize "should fix" items and ask me whether to address them
   now; any I decline go in the description as not handled.
5. Update the task file (tick the acceptance criteria, set `Status: review`, add a log line) and
   commit it. Status changes only now: the review gate asks for a review as soon as a task is
   in review, which would cut into the steps above.
6. Push and open the PR (`gh pr create`) with the description.
   - **Interactive:** show me the branch and the PR description, and wait for my OK first.
   - **Parallel or auto:** push the feature branch (`git push -u origin HEAD`) and open the PR
     without asking. If the push or `gh` is refused (permissions, no remote, not signed in),
     stop and report the branch and the PR description instead of working around it.
7. Never push to a protected branch (main, master, production, release, or
   `HARNESS_PROTECTED_BRANCHES`). In parallel and auto modes the guard blocks it and any force
   push; in interactive mode it only blocks force pushes, so the rule is yours to keep.
