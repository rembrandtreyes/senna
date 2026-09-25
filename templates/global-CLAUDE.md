# Me (global, lives in ~/.claude/CLAUDE.md)

Keep this short: only things true in every project. Project details belong in the project CLAUDE.md,
and stack conventions belong in harness skills.

## How I work
- Stacks: TS (React/Next/Expo), Go, Rust (for performance-critical work).
- I prefer: <terse answers / explanations of tradeoffs / ...>
- When unsure about intent, <ask one question | make a reasonable assumption and state it>.
- Don't: <add dependencies without asking | reformat unrelated code | write summaries I didn't ask for>

## Git
- Conventional commits (`feat:`, `fix:`, `refactor:`...), referencing the task ID.
- Feature branches only. Never commit to main.

## Harness
- Work from task files (`tasks/`, see the task-files skill). The active one is in `.harness/current-task`.
- Run /retro at the end of substantial sessions and /handoff before stopping mid-task.
