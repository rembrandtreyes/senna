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
| `/present`, deck-narrator, deck-diagrammer, visual-qa, renderer | skill, agents, scripts | 6 ✓, 7 ✓ |
| `scripts/model.mjs`: LikeC4 proposal → Mermaid flows in spec.md, deck diagram | script | 8 ✓ |
| `/publish`, adapters (`artifact`, `static`; `vercel` on request, untested) | skill, docs | 9 ✓ |
| `/feedback`, `scripts/feedback.mjs` | skill, script | 9 ✓ |
| SessionStart spec report, deck staleness hook | hooks | 10 ✓ |
| `/breakdown` from a spec, reviewer R-ID check (`rid-check.sh`) | in core | 10 ✓ |

Start by describing the work in plain words; the router picks it up. There is no `/plan`
command: that's Claude Code's built-in plan mode, which the router works inside.

Depends on `core` (debugger agent, `/breakdown`, reviewer) and reuses `security-auditor` from `ops`.
