# plan

The planning pipeline from `docs/planning-pipeline.md`: route a request, then take features and
projects through PRD → spec → present → review → feedback → build, with requirement IDs (`R-n`)
traced end to end. Artifacts for each feature live in `specs/<slug>/` in the target project.

Built in the order listed in HANDOFF.md (Phase 2). Components land here as they are built:

| Component | Kind | Build step |
|---|---|---|
| intake router (`route`) | skill | 2 ✓ |
| `/prd`, prd-critic | skill, agent | 3 ✓ |
| `/spec`, designer, spec-critic | skill, agents | 4 ✓ |
| `/design-review`, architecture / sre / product reviewers | skill, agents | 5 ✓ |
| `/present`, deck-narrator, deck-diagrammer, visual-qa, renderer | skill, agents, scripts | 6 ✓ |
| publish + feedback adapters, `/feedback` | scripts, skill | 9 |
| deck staleness hook | hook | 10 |

Depends on `core` (debugger agent, `/breakdown`, reviewer) and reuses `security-auditor` from `ops`.
