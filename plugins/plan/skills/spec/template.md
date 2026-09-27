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
| Req | Design section | Test(s): layer and what it checks | Milestone |
|---|---|---|---|
| R-1 | | | |

## Background and current system
How it works today (brownfield first): components, data, flows, and the pain. Link code.

## Proposed design
### Architecture
The proposal is `model/proposal.c4` (LikeC4; `npx likec4 start specs/<slug>/model` to browse).
Here: a table of the components it adds, changes, or removes, each with its responsibility and
owner. Without a model, the table covers every component, before and after.
### Data model and migrations
A table: entity, key fields, invariants (uniqueness, lifecycle states, retention), owner. Then
migration steps, backfill, and how old and new code coexist during rollout. No DDL; column
types and indexes are the implementer's call unless one is a decision (then it's an ADR).
### APIs and contracts
A table: endpoint or message, purpose, success and error codes, R-IDs. Link the contract file
(OpenAPI, JSON Schema, proto) as the source of truth instead of pasting shapes (see the
api-contracts skill). At most one short example payload per new message type.
### Key flows
One subsection per flow: the generated sequence diagram, at most ~7 numbered steps, then a
failure table (failure, what happens, what the user sees). No queries or pseudo-code.
Each flow is a dynamic view in `model/`; `<!-- flow:<viewId> -->` marks where
`model.mjs flows` writes its diagram.
#### <Flow name> (R-n)
<!-- flow:<viewId> -->
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

## Test strategy
Each requirement's test and its layer are in Requirement coverage ("integration: retries after a
500"). Pick the cheapest layer that would catch the bug: static (types, schema) < unit <
component < integration (real dependency) < contract < E2E. Here, only:
- **Riskiest boundary:** where this feature's bugs will come from (a database schema or access
  policy, a third-party API, a runtime) and what checks it against the real thing, not a mock:
  an integration test on a real dependency, a contract test, or a static type check.
- **Mocks:** each one that could disagree with reality, and what verifies it.
- **E2E:** the critical journeys that get one, or "none" and why. Load and failure-injection
  tests only where Performance or a flow's failure table calls for them.

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

