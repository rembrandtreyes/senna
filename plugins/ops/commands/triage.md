---
description: Triage a production error from Sentry into a root cause and a fix
argument-hint: <sentry issue id or url, or a description>
---

Triage: $ARGUMENTS

1. Use the Sentry tools to pull the issue: stack trace, latest events, breadcrumbs, affected
   release/commit, frequency, and users affected. If Sentry tools aren't connected, say so and
   ask me to paste the trace.
2. Assess impact in 2 lines: how bad, how widespread, and whether it's getting worse.
3. Hand the investigation to the **debugger** subagent with everything you gathered.
4. If the fix is non-trivial, create a task file (task-files skill) with the reproduction as the
   first acceptance criterion. Otherwise fix it, and list the regression test.
