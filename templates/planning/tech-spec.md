# Tech spec: <feature name>

Status: draft | in review | approved | implemented   ·   Version: v1   ·   Author: <name>
Reviewers: <names / lenses>   ·   PRD: specs/<slug>/prd.md   ·   Feedback closes: <date>

## Summary
One paragraph: what we're building and how, in plain language. Then **the ask**: the decision
this review needs.

## Goals and non-goals
Goals map to PRD requirement IDs. Non-goals are prominent here, not buried.

## Background and current system
How it works today (brownfield first): components, data, flows, and the pain. Link code.

## Proposed design
### Architecture
Reference LikeC4 views in `model/` (before and after). Every component: responsibility and owner.
### Data model and migrations
Schemas, indexes, migration steps, backfill, and how old and new code coexist during rollout.
### APIs and contracts
Endpoints/messages, request/response shapes, errors, versioning. Contract file is the source
of truth (see api-contracts skill).
### Key flows
One subsection per flow, including failure paths (timeouts, retries, partial failure).
Each flow becomes a LikeC4 dynamic view and a deck scenario.
### Performance and scale
Expected load, limits, latency budget per hop, and capacity math.

## Alternatives considered
At least two, each with why it was rejected. This stops reviewers re-proposing discarded ideas.

## Security and privacy
Threat model: assets, entry points, trust boundaries, and the mitigations for each.

## Observability
Metrics, logs, traces, dashboards, and alerts (with thresholds and who gets paged).

## Test plan
Unit, integration, contract, load, and failure-injection tests. Map tests to requirement IDs.

## Rollout and rollback
Stages with gates to advance and a rollback method for each. Feature flags named.

## Fallback plan
If the proposed design fails in production or in build, what's the next best alternative?

## Cost
Infra, licenses, and ongoing operational burden.

## Risks
| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|

## Milestones
Each milestone lists the requirement IDs it delivers. `/breakdown` turns these into tasks.

## Open questions
| ID | Question | Owner | Needed by | Decision |
|---|---|---|---|---|

## Changelog
Date every change after the first review. Summarize what changed and why (link feedback IDs).
- <date> v1 first draft

---
### spec-critic checklist (the harness runs this before /present)
- [ ] Every PRD requirement maps to a design section, a test, and a milestone.
- [ ] Non-goals appear in the first screen of the document.
- [ ] At least two alternatives with rejection reasons.
- [ ] Every flow covers its failure paths.
- [ ] Rollout has gates AND a rollback per stage.
- [ ] Observability names the alerts that would catch this feature breaking.
- [ ] Security section names trust boundaries.
- [ ] Final read-through: could an engineer implement this from the spec alone?
