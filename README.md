# my-harness

A personal Claude Code harness, packaged as a plugin marketplace so every project gets the same
guardrails, verification, and workflow, and improves in one place.

```
.claude-plugin/marketplace.json   lists the plugins below
plugins/
  core/        every project: session context, guardrails, handoffs, retro loop,
               explorer/reviewer/debugger agents, /breakdown /ship /retro /handoff /worktree
  lang-ts/     React/Next/Expo: format+lint on edit, typecheck(+tests) on stop
  lang-go/     gofmt on edit, build+vet(+tests) on stop
  lang-rust/   rustfmt on edit, clippy(+tests) on stop, perf workflow skill
  ops/         security-auditor agent, /triage via Sentry MCP, api-contracts skill
  plan/        planning pipeline: router, /prd, /spec, reviewers, /present, /feedback
  lang-template/  copy to add Python, Java, Kotlin, Swift... (not listed in marketplace)
shared/common.sh  canonical hook library (synced into each plugin)
docs/             planning-pipeline.md: the Phase 2 design (PRD → spec → present → review → build)
reference/present working review-deck template, schema, renderer, example data
templates/        global + project CLAUDE.md, settings, gitignore, override examples
scripts/          sync-common.sh, validate.sh
```

## Prerequisites
`git`, `jq` (the hooks rely on it; without it they skip and warn), and `bash`. Optional: `gh`
for PRs, `lsof` for port checks, and the usual toolchains (`node`, `go`, `cargo`/`rustfmt`).

## Install

1. Replace `YOUR_NAME` / `YOUR_GITHUB_USER` everywhere, then push this repo to GitHub (private
   is fine).
2. In Claude Code:
   ```
   /plugin marketplace add YOUR_GITHUB_USER/my-harness
   /plugin install core@my-harness
   ```
3. Global setup: copy `templates/global-CLAUDE.md` to `~/.claude/CLAUDE.md` and make it yours.
4. Per project:
   - copy `templates/project-settings.json` to `<project>/.claude/settings.json` and flip on the
     language plugins that project uses. Committing this makes the plugins install automatically
     for anyone who trusts the repo.
   - copy `templates/project-CLAUDE.md` to `<project>/CLAUDE.md` and fill it in
   - append `templates/gitignore-snippet.txt` to `.gitignore`
   - `mkdir tasks .harness`

While developing the harness itself, test locally with
`/plugin marketplace add /path/to/my-harness`, and run `/reload-plugins` after editing hooks or
agents. Skill edits apply immediately.

## Modes

| Mode | Set by | Edit hooks | Stop hooks | Extra guards |
|---|---|---|---|---|
| `interactive` (default) | nothing | format + lint | typecheck/build only, blocks once | — |
| `parallel` | `worktree.sh` writes `.harness/mode` | same | + tests, up to 3 retries | progress log, no push from main, no publish/sudo |
| `auto` | `HARNESS_MODE=auto claude` | same | + tests, up to 3 retries | same as parallel |

Stop hooks only run for languages whose files actually changed, so a TS-only change never waits
on `cargo test`. After the retry budget is spent, the harness hands control back to you instead
of looping. Tune it with `HARNESS_MAX_STOP_RETRIES`, `HARNESS_GO_TEST_FLAGS=-race`, and
`HARNESS_CLIPPY_FLAGS="-D warnings"`.

For unattended runs, copy `templates/settings.local.auto.json` to
`<project>/.claude/settings.local.json` so routine commands don't stall on permission prompts.
Set `HARNESS_NTFY_TOPIC=<topic>` to get "Claude needs you" alerts on your phone via ntfy.sh.

## The workflow loop

```
/breakdown <idea> explorer agents map the code, then task files in tasks/ with acceptance criteria
/worktree T-3 T-4 one worktree per independent task (unique ports, env copied, deps installed)
  ...implement... hooks format/lint every edit and verify at every stop
/ship             checks, then reviewer + security-auditor in parallel, fix blockers, PR
/handoff          before stopping mid-task (auto-loaded next session)
/retro            capture lessons; anything recurring gets promoted to a skill or hook
```

## Adapting to any stack (without forking)

Drop executable scripts in a project's `.harness/checks/` to replace a plugin's defaults for that
project:

| File | Replaces |
|---|---|
| `ts-edit.sh <file>` / `ts-stop.sh` | lang-ts hooks |
| `go-edit.sh <file>` / `go-stop.sh` | lang-go hooks |
| `rust-edit.sh <file>` / `rust-stop.sh` | lang-rust hooks |

A non-zero exit means the check failed, and the output goes to Claude. `HARNESS_MODE` is set for
you. See `templates/harness-checks/ts-stop.sh` for an Nx example. Add project-specific command
bans (one regex per line) in `.harness/blocked-commands.txt`.

For a new language, copy `plugins/lang-template`.

## Taking it to a new job

The harness is built so the parts that are *you* travel, and the parts that are *theirs* plug in:

1. **Check the policy first.** Plugins run shell hooks on your machine and send code to a model.
   Confirm your employer allows Claude Code and third-party plugins on company repos before
   enabling anything.
2. **Keep this repo personal.** Never commit employer code, internal URLs, secrets, or
   proprietary conventions here.
3. **Create a company marketplace** in their GitHub org by copying `core` plus the relevant
   `lang-*` plugins. Add a `company` plugin with their conventions, CI commands, and internal MCP
   servers. Teammates install from there, and changes go through their review.
4. **Map their build system** with `.harness/checks/` overrides (Bazel, Gradle, Nx, Turborepo...)
   rather than editing the language plugins.
5. **Promote generic improvements back** to your personal repo only if they contain nothing
   company-specific.

## Maintaining
- Edit hook helpers in `shared/common.sh`, then run `scripts/sync-common.sh`.
- Run `scripts/validate.sh` before pushing. It checks JSON, bash syntax, executability, synced
  copies, versions, and frontmatter.
- Bump `version` in both `plugin.json` and `marketplace.json` when you change a plugin.
- Grow the harness from failures: when something goes wrong twice, `/retro` should turn it into
  a hook (must always happen) or a skill (knowledge).
