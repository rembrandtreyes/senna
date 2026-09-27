# Feedback ledger: <feature name>

Spec: spec.md   ·   Feedback closes: <date>   ·   Sign-off: <owner, date> (set by /feedback)

Every item gets a status and a resolution. Status: open | accepted | rejected | deferred.
Rejected and deferred items need a reason. Close feedback at a set date; late items go to v2.
Severity: critical (blocks approval) | major (fix before build) | minor (optional).

## Lenses
| Lens | Spec version | Date | Findings | Critical |
|---|---|---|---|---|

## Items
| ID | Ver | Source | Reviewer | Section | Kind | Sev | Summary | Status | Resolution | Addressed in |
|---|---|---|---|---|---|---|---|---|---|---|
| F-1 | v1 | agent:architecture | architecture-reviewer | Key flows › F2 | concern | major | | open | | |

Source: `agent:<lens>`, or `<source> (<ref>)` for reviewer feedback, where source is `artifact db`,
`artifact comment`, `vercel comment`, `PR review`, `PR comment`, or `deck export`, and ref is the
source's own id (/feedback uses it to skip items it already imported).
Kind: concern | question | approve | decision.

## Details
Only for items that need more than the one-line summary. Keep each to a few lines.

### F-1
Evidence: <spec section or file:line>. Suggested change: <what to do>.
