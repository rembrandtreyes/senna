---
type: llm
focus: trace
weight: 1
---

The response says the rule in apps/web/.claude/rules/testing.md never loads because its paths resolve from apps/web/ (the folder holding .claude/), and gives src/**/*.test.tsx (or an equivalent pattern relative to apps/web/) as the fix.
