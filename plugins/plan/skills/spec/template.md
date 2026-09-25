# Tech spec: <feature name>

Status: draft | in review | approved | implemented   ·   Version: v1   ·   Author: <name>
Reviewers: <names / lenses>   ·   PRD: specs/<slug>/prd.md   ·   Feedback closes: <date>

<!-- Budget: ~300 lines (spec-lite) or ~600 (project). Decisions and contracts, not code.
     Detail that's cheap to change later is the implementer's call. -->

## Summary
One paragraph: what we're building and how, in plain language. Then **the ask**: the decision
this review needs.

## Goals and non-goals
Goals map to PRD requirement IDs. Non-goals are prominent here, not buried.

### Requirement coverage
| Req | Design section | Test(s) | Milestone |
|---|---|---|---|
| R-1 | | | |

## Background and current system
How it works today (brownfield first): components, data, flows, and the pain. Link code.

## Proposed design
### Architecture
Every component: responsibility and owner, before and after. Reference LikeC4 views in `model/`
when the project has them; otherwise a component table is enough.
### Data model and migrations
A table: entity, key fields, invariants (uniqueness, lifecycle states, retention), owner. Then
migration steps, backfill, and how old and new code coexist during rollout. No DDL; column
types and indexes are the implementer's call unless one is a decision (then it's an ADR).
### APIs and contracts
A table: endpoint or message, purpose, success and error codes, R-IDs. Link the contract file
(OpenAPI, JSON Schema, proto) as the source of truth instead of pasting shapes (see the
api-contracts skill). At most one short example payload per new message type.
### Key flows
One subsection per flow: at most ~7 numbered steps, then a failure table (failure, what
happens, what the user sees). No queries or pseudo-code.
Each flow becomes a LikeC4 dynamic view and a deck scenario.
### Performance and scale
Expected load, limits, latency budget per hop, and capacity math: the numbers and the one-line
reasoning behind each, not the derivation.

## Alternatives considered
At least two, each with why it was rejected. This stops reviewers re-proposing discarded ideas.
The losing designs from /spec's design round go here; the decision itself is `adr/001-*.md`.

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

