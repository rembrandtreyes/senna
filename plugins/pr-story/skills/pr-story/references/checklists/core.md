# Core checklist (every change)

1. **Intent.** Does the code do what the story says? Trace one real path end to end, from the
   entry point (route, command, event, screen) to the effect (row written, response sent, UI
   shown), and name it in the story.
2. **Unhappy paths.** Bad, missing, or oversized input; empty states; nulls; a duplicate
   submission; a dependency that is down or slow. For each, what happens and what the user sees.
3. **Tests.** Does a test cover the failure paths, not only the happy one? Would it fail if the
   behaviour broke? If the testing skill (core plugin) is installed, grade new tests against its
   rubric. Behaviour with no test goes in the Untested section.
4. **Operability.** When this fails in production, how would anyone know: a log line, a metric,
   an alert? How do you roll it back: a revert, a flag, a down migration? Anything to do before
   or after deploy?
5. **This repo's lessons.** Each `[review]` line in `.harness/learnings.md` for these files or
   areas, asked as a question.

A behaviour-preserving refactor has one central claim, "no behaviour change." Back it with the
existing tests passing unchanged and no change to public signatures or outputs.
