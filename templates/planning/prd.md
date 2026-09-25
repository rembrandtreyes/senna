# PRD: <feature name>

Status: draft | in review | approved   ·   Version: v1   ·   Owner: <name>   ·   Updated: <date>
Tech spec: specs/<slug>/spec.md (once written)

## Problem
What's broken or missing, for whom, and the evidence (incidents, tickets, data, quotes).
Write this before anything else. It must NOT describe the solution.

## Users and situations
Who hits this problem, in what situation, and what they do today instead.

## Success metrics
| Metric | Baseline | Target | By when | Who checks it |
|---|---|---|---|---|
| | | | | |

Every metric traces to the problem above. No target, timeframe, or owner = not a metric.

## Requirements
Each is testable by someone who didn't write it. Use measurable language ("p95 < 500 ms", not "fast").

- **R-1** <requirement>
  - Acceptance: Given <context>, when <action>, then <observable result>.
- **R-2** …

### Non-functional requirements
Performance, reliability, security, privacy, accessibility, compliance, with numbers.

## Non-goals
What a reasonable person might assume is included but isn't. Keep this near the top of the
reader's mind; buried non-goals invite scope creep.

## Unhappy paths
Errors, empty states, limits, abuse, partial failure, and what the user experiences in each.

## Dependencies and assumptions
Teams, systems, and facts this relies on. Mark each assumption as verified or unverified.

## Risks

## Open questions
| ID | Question | Owner | Needed by |
|---|---|---|---|
| Q-1 | | | |

## Changelog
- <date> v1 created

---
### prd-critic checklist (the harness runs this before /spec)
- [ ] The problem statement doesn't paraphrase the feature.
- [ ] Evidence is cited for the problem.
- [ ] Every metric has a baseline, target, timeframe, and owner.
- [ ] Every requirement has an ID and a Given/When/Then acceptance check.
- [ ] Non-goals exist and are specific.
- [ ] Unhappy paths are covered, not just the happy path.
- [ ] Unverified assumptions are listed as such.
- [ ] Open questions have owners.
