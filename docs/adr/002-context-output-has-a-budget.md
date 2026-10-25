# ADR-002: Hook output that becomes context has a budget

Status: accepted   ·   Date: 2026-10-25
Applies to: plugins/*/hooks/scripts/**
Check: a hook whose output becomes context printing a file or command output with no cap (head -n or a byte budget), or printing its instructions after content that can grow

## Context
SessionStart output becomes Claude's context, and Claude Code caps it at 10,000 characters.
Several plugins add to the same session (core, plan, decision-log), and the files they print
(tasks, handoffs, learnings, decision logs) grow without limit, so the content printed last is
what gets cut.

## Decision
We will cap every piece of variable content, either with `head -n` or with a byte budget in awk
that cuts on whole UTF-8 characters. Instructions are printed before content that can grow, and
each cap gets a test with an oversized fixture.

## Alternatives
- **Trusting files to stay small:** a long decision log or handoff would quietly push the
  instructions out of context.
- **One budget shared by all plugins:** a plugin can't see what the others print.

## Consequences
Long content is shortened, with a pointer to the file that has the rest. Tests need oversized
fixtures. A future raise of the cap needs only the budgets changed.
