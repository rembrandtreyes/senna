---
name: testing
description: Rubric for deciding what to test, at which layer, and whether a test is worth keeping. Use whenever writing, fixing, or reviewing tests, on EVERY bug fix (the regression test), when a test is flaky, when deciding whether to mock something, and when a spec's Test strategy or a task's Requirements need tests. Also use when asked "are we testing the right things?"
---

# Testing

Aim tests where the bugs actually come from. In real projects, a large share of shipped bugs are
mocks that agreed with the code's assumptions and disagreed with reality (a database schema or
access policy, a third-party API's rules), and every one of them had passing tests.

## The rubric
Ask these of every test you write, change, or review:
1. **What user-visible behavior or contract does it protect?** If you can't say, it's testing
   implementation. Name it in the test name.
2. **Would it survive a refactor that keeps that behavior?** Asserting on internal calls,
   private state, or call counts of a mock fails this.
3. **Would it fail if that behavior broke?** Check by breaking the code once (flip a condition,
   drop a field) and watching it fail. A test that can't fail is worse than none.
4. **Is it deterministic and hermetic?** No sleeps, wall-clock time, random seeds, shared state
   between tests, test order, or the network outside a controlled boundary.
5. **Does its failure message say what broke?** A diff of want vs. got, and the input that
   caused it, not "expected true".
6. **Does it mock something that could disagree with reality? If so, what verifies the mock?**
   Databases (schema, constraints, access policies), third-party APIs (schema rules, errors,
   limits), and runtimes (edge, serverless, device) are the usual liars. Something must check
   the mock against the real thing: an integration test on the real dependency, a contract test,
   fixtures recorded from real responses, or a static type generated from the real schema.

## Pick the cheapest layer that catches the bug
static check (types, schema, lint) < unit < component < integration (real dependency) <
contract < E2E.
- Prefer a static check whenever one can make the bug impossible: a type generated from the DB
  schema, a column list that `satisfies` it, a schema-validated config. It never goes stale.
- Pure logic gets unit tests. Pull it out of components and handlers so it can.
- Code whose risk is the boundary gets an integration test against the real dependency, not a
  unit test with the boundary mocked.
- E2E only for the critical journeys the spec names. Get the existing E2E suite running in CI
  before writing more.
The language skills (react-next, go, rust, expo) say which tool covers each layer.

## Bug fixes
1. Before fixing, ask which layer would have caught it, and write the failing test there.
2. If the bug was a mock that disagreed with reality, fix the check, not just the code: the new
   test hits the real thing, or the mock gets verified against it.
3. The test fails before the fix and passes after. Say so in the report.
4. Look for siblings: other code with the same mock or the same assumption.

## Flaky tests
A flaky test is a bug in the test or the code, never something to retry away. Find the source
of nondeterminism (time, ordering, shared state, a real network, a race) and remove it. Don't
add sleeps, retries, or skip markers without a linked task.

## Reviewing tests
For each test in the diff, give only the failing rubric items, quoted, with the fix. Also flag
behavior the change adds with no test at all, and tests at a costlier layer than needed. If a
task has `Requirements:`, every R-ID must be cited by a test (see task-files).
