# Audit report template

`.harness/icm/audit-<YYYY-MM-DD>.md`. Keep it short enough to read in two minutes; the script's
raw output can go in a collapsed section at the end.

```markdown
# ICM audit: <repo> (<YYYY-MM-DD>)

Claude Code <version> · read-only · tokens ~ bytes/4

## Summary
<2-3 sentences: what's already good, what's broken.> Findings: N blocker, N should, N consider.

| Layer | What the repo uses | Cost |
|---|---|---|
| L0+L1 launch | ... | ~N tok, N lines |
| L2 areas | ... | up to ~N tok on <heaviest path> |
| L2 workflow | ... | ... |
| L3 reference | ... | ... |
| L4 working | ... | ... |

## Blockers
### B1. <What never reaches Claude, in plain words>
- **Files:** ...
- **Cause:** ...
- **Verified:** <probe result and version, or "by the docs rule" when not probed>
- **Impact:** ...
- **Fix:** <smallest change; respect the repo's conventions>

## Should fix
### S1. ...

## Consider
- **C1.** ...

## Checked and fine
<Things a reader might suspect but that hold up, so nobody re-checks them.>

## Left to /doctor prompt-audit
<Wording, contradictions, dead command references, if you noticed any.>

<details><summary>Script output</summary>

...
</details>
```
