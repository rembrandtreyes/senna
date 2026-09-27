---
name: test-audit
description: Fix-commit audit that shows where a project's bugs actually come from and which test layer would have caught each one. Use when the user types /test-audit, asks "are we testing the right things?", "where do our bugs come from?", or wants to decide on a testing investment (integration tests, E2E, mutation testing, more coverage), when setting up the harness on an existing project, and quarterly (/retro suggests it). Read-only; proposes changes, doesn't make them.
---

# Test audit

Classify the last N fix commits (default 40) by root cause and by the cheapest layer that would
have caught each one, then report the pattern. The testing skill's rubric and layer ladder are
the vocabulary: static < unit < component < integration (real dependency) < contract < E2E.

## 1. Find the fix commits
```
git log --no-merges -i -E --grep='^(fix|hotfix|bug)|^revert|(^|[^a-z])fix(es|ed)?([^a-z]|$)' \
  --format='%h %ad %s' --date=short -n <N*2>
```
(No `\b`: macOS git's regex doesn't support it. `--grep` matches any line of the message, so
expect some noise.)
Drop commits that aren't bug fixes (typo fixes, lint, dependency bumps, "fix tests" that only
touched tests for a non-bug) and keep the N most recent real ones. If fewer than ~15 remain, say
the sample is small and the pattern is a hint, not a finding. If the project doesn't prefix fix
commits, ask the user how to find them (PR labels, issue links, Sentry references).

## 2. Classify each commit
Read `git show --stat <sha>`, then the relevant hunks, the commit message, and the linked issue
or PR if there is one. With more than ~15 commits, split them into batches across parallel
explorer subagents and give each the fields below.

For each commit record:
- **Cause:** logic · component/UI · **mock disagreed with reality** (name what: DB schema,
  constraint, or access policy; a third-party API's rules; a runtime) · runtime/environment
  (edge, serverless, device, browser) · config/deploy · data/migration · concurrency · journey
  (only visible across pages or services).
- **Cheapest catching layer:** the lowest rung that would have failed before the fix. Choose
  static whenever a type or schema check could have made the bug impossible. "None practical"
  is allowed (caught only by monitoring); say why.
- **Tests at the time:** did tests covering this code exist and pass while the bug shipped?
  Passing mocked tests on the broken path mean the cause is "mock disagreed with reality".
- **Fix's test:** did the fix add a test, and at which layer? Did it hit the real thing?
- **Confidence:** high, or low with the one fact that would settle it.

## 3. Report
Write `.harness/test-audit-<YYYY-MM-DD>.md`. Don't commit it or create a branch: tell the user
it's meant to be committed, since the next audit compares against it. It holds:
1. **Table:** sha, date, subject, cause, cheapest layer, tests at the time, fix's test,
   confidence.
2. **Counts** by cause and by cheapest layer. Call out the share of bugs that had passing tests.
3. **The pattern** in 2–3 sentences: where this project's bugs come from.
4. **Recommendations,** at most three, ranked by how many of these bugs each would have caught:
   for example, a real-dependency integration layer, types generated from the DB schema, running
   the existing E2E suite in CI, or Browser Mode for layout bugs. Name the commits each covers.
   Mutation testing or more E2E only if the data points there.
5. **Boundary candidates:** paths that keep appearing in mock-disagreement bugs, drafted as
   `.harness/checks/boundaries.txt` rules (`<boundary glob> => <real-dependency test globs>`).
6. **Since last audit:** if an earlier `.harness/test-audit-*.md` exists, what moved.

Then give the user the summary and ask before writing `boundaries.txt`, changing a lang skill,
creating tasks for the recommendations, or touching git. A lesson that applies beyond this project (a stack
pattern) is a /retro promotion candidate for the harness.
