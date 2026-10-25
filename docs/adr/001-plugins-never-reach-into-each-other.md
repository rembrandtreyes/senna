# ADR-001: Plugins never reach into each other's files

Status: accepted   ·   Date: 2026-10-25
Applies to: plugins/**
Check: a path into another plugin's folder in a hook, script, command, agent, or skill, or another plugin's skill or agent used without "if listed" or "if installed"

## Context
Claude Code installs each plugin into its own versioned cache folder, so a plugin can't read
files outside its own folder. Some plugins are opt-in (pr-story, decision-log, ops), and core
has to work without them.

## Decision
We will have each plugin carry what it needs. Shared hook code is copied into each plugin by
`scripts/sync-common.sh`, and a feature that uses another plugin names its skill or agent and
uses it only if it's listed, as `/ship` and `/vet` do with pr-story and security-auditor.

## Alternatives
- **One cross-language hook dispatcher in core:** dropped, because it can't reach the language
  plugins' files once installed.
- **Folding the opt-in plugins into core:** everyone would pay for them, such as decision-log's
  check at every stop, which takes about 3s.

## Consequences
`common.sh` exists in several copies, kept identical by `validate.sh`. A feature that needs
another plugin does less without it instead of failing. Reversing this would need Claude Code to
support dependencies between plugins.
