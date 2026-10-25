---
description: Review a PR or branch - its story (pr-story), bugs and tests, the project's decision records (docs/adr/), and current best practice for the dependencies it uses - as one report
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

   Blockers:          <file:line: problem (source: reviewer, ADR-NNN, best-practices URL, security)>
   Should fix:        ...
   Decision records:  <ADR-NNN title: kept | broken at file:line>  (or "none apply", "no docs/adr/")
   Versions:          <package installed → latest; one line per upgrade note>
   Not checked:       <checks not run, practice not researched, and why>
   Questions for the author: <at most five, most important first>

   <details><summary>Full reports</summary> each agent's output, and the claims table </details>
   ```
6. **After.** Post nothing to GitHub unless asked (then `gh pr review <n> --comment
   --body-file <file>`). When the user wants a finding to become a standing rule, offer `/adr`.
   pr-story proposes a `[review]` lesson for anything notable.
