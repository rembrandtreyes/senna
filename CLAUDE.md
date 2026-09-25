# my-harness (the harness repo itself)

This repo is a Claude Code plugin marketplace: a personal harness of hooks, agents, commands, and
skills shared across all of the owner's projects. You are working **on** the harness, not **with**
it. See README.md for the architecture and HANDOFF.md for the current state and remaining work.

## Rules for editing this repo
- **Hook helpers live in `shared/common.sh`.** Never edit a `plugins/*/hooks/scripts/common.sh`
  directly. Edit the shared copy, then run `scripts/sync-common.sh`. (Installed plugins can't
  reference files outside their own folder, which is why each plugin carries a copy.)
- **Run `scripts/validate.sh` after every change.** Also run `shellcheck -x -S warning -e SC1091`
  on any script you touch, if shellcheck is installed.
- **Portable bash only.** The owner may be on macOS (bash 3.2, BSD find/sed). No `mapfile`,
  associative arrays, `${var,,}`, `sed -i` without a suffix argument, or GNU-only flags.
- **Hook exit codes matter.** Exit 0 = allow/ok. Exit 2 = block, and stderr goes to Claude. Any
  other non-zero exit = a non-blocking error shown to the user. A hook must never exit 2 by
  accident, so wrap anything that can fail.
- **Edit hooks must stay fast** (under ~2s): format and lint a single file only. Anything slow
  belongs in a Stop hook, gated on `changed_files` so untouched languages are skipped.
- **Test hooks by piping JSON** into them with `CLAUDE_PROJECT_DIR` set to a scratch git repo
  (never this repo). For example:
  `echo '{"tool_input":{"command":"git push --force"}}' | CLAUDE_PROJECT_DIR=/tmp/scratch plugins/core/hooks/scripts/guard-bash.sh; echo $?`
- **Version bumps:** when you change a plugin, bump `version` in both its `plugin.json` and
  `.claude-plugin/marketplace.json`. validate.sh checks that they match.
- **Skills:** frontmatter needs `name` and a "pushy" `description` that says when to use the skill.
  Body content should cover only what Claude wouldn't do by default.
- **Nothing employer-specific** (code, internal URLs, secrets, proprietary conventions) ever goes
  in this repo. See the "Taking it to a new job" section of the README.
