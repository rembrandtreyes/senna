---
description: Review a PR or branch - its story (pr-story), bugs and tests, the team's decision records, and current best practice for the dependencies it uses - as one report
argument-hint: [PR number | base branch] [focus, e.g. security]
---

Review a change for a human reviewer. Input: $ARGUMENTS

1. **What to review.**
   - **A PR number:** `gh pr view <n> --json baseRefName,headRefName,headRefOid,isCrossRepository`
     (not the title or body yet: the story is told from the code first), then
     `git fetch origin <baseRefName> pull/<n>/head`, which leaves the working tree alone. Base
     is `origin/<baseRefName>`, head is `<headRefOid>`, and the code isn't checked out.
   - **A base branch, or nothing:** the current branch and its uncommitted changes, against that
     base (default `origin/main`).
   - Nobody runs a PR's code or tests unless it's checked out, and never for a PR from a fork
     (`isCrossRepository`) unless the user says so; then only in a scratch worktree
     (`git worktree add --detach <scratch path> <headRefOid>`).
2. **The diff, for the research agent** (it has no shell): write
   `git diff -U10 <merge-base> <head>` (or against the working tree, for the current branch) to
   `.harness/vet/<pr-N or branch, / as __>.diff`.
   **The decision records:** when `.harness/records-source` names a URL and
   `.harness/records/index.md` is missing or was synced more than a day ago, run the
   **records-sync** subagent with the URL first. If it can't reach the source, go on with the copy
   you have and say so in the report.
3. **Dispatch in one message, in the background:**
   - the **reviewer** subagent: the base and head, whether the code is checked out, the harness
     scripts dir from the session context, and the task file when it's the current branch's.
     For a PR, tell it to read the description itself (`gh pr view <n> --json body`) and check
     its claims, and that there's no task.
   - the **best-practices** subagent: the diff file, and the focus if one was given.
   - the **security-auditor** subagent, if installed.
4. **The story, meanwhile.** If the `pr-story` skill is listed, invoke it in reviewer mode with
   the same PR number or base, and the focus as its flavour when it names one. Otherwise retell
   the change from the diff in a few lines, and say pr-story isn't installed.
5. **One report**, when all have returned. A finding from two sources is listed once, naming
   both. The verdict is FIX FIRST if any source has a blocker.
   ```
   ## Vet: <PR #n title, or branch> · <PASS | FIX FIRST>
   <the story: TL;DR and reading order>

   Blockers:          <file:line: problem (source: reviewer, a record's ID, best-practices URL, security)>
   Should fix:        ...
   Decision records:  <ID title: kept | broken at file:line>  (or "none apply", "none found";
                      say when the copy is stale or couldn't be synced)
   Versions:          <package installed → latest; one line per upgrade note>
   Not checked:       <checks not run, practice not researched, and why>
   Questions for the author: <at most five, most important first>

   <details><summary>Full reports</summary> each agent's output, and the claims table </details>
   ```
6. **After.** Post nothing to GitHub unless asked (then `gh pr review <n> --comment
   --body-file <file>`). When the user wants a finding to become a team rule, offer to draft a
   decision record for them to propose; the team writes its records, so never add one yourself.
   pr-story proposes a `[review]` lesson for anything notable.
