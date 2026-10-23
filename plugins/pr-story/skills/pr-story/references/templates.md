# Templates

Fill in what applies and delete what doesn't, including whole sections. Angle brackets are
placeholders. The examples show the level of specificity to aim for.

## Author: the PR description

```markdown
## TL;DR
<The problem, in one line.>
<The core change, in one line.>
Risk: <low | medium | high>: <why, in one clause>

## The story
<Two to five sentences: what was wrong or missing, why it matters now, and the one change
everything else hinges on (`path:40-88`).>

Read in this order:
1. **Careful:** `src/invites/create.ts:22-61`: <the change everything depends on, and what could go wrong>
2. **Careful:** `src/invites/routes.ts`: <why it changed, in a clause>
3. **Skim:** <renames, plumbing, generated files>: mechanical

## Decisions
- **<What was chosen>** over <the alternative>: <why>. (<ADR link, if one exists>)

## Checklist
| Question | Answer | Evidence |
|---|---|---|
| What does the user see when the invite email is already a member? | 409, and the form says "already on the team" | `invites.test.ts::rejects existing member` |
| Is a double-submitted invite sent twice? | **Not handled**: two emails go out | none |

## Proof
<details><summary>Before and after</summary>

<A request and response, CLI output, or a screenshot path, before and after.>

</details>

## Blast radius
- <Caller, feature, or consumer outside the diff>: <how it could be affected, and whether a test covers it>

## Untested
- <Behaviour with no test, and why that's acceptable or not>

<details><summary>Size: <N> changed lines, over the <limit>-line limit</summary>

Suggested split:
1. <PR 1: files, what it does on its own>
2. <PR 2: files, what it depends on>

</details>

Task: <tasks/T-012-...md> · Spec: <specs/<slug>/spec.md> · Closes <#45>
```

## Reviewer: the retelling

```markdown
## The story, as the code tells it
<Two to five sentences, written before reading the author's description.>

## Where it differs from the description
- <The description says X; the code does Y (`path:line`).>

## Claims
| Claim | Verdict | Evidence |
|---|---|---|
| "Retries are idempotent" | contradicted | `queue.ts:88` retries without the dedupe key |
| "Covered by tests" | unsupported | no test exercises the 409 path |
| "Old clients keep working" | confirmed | `v1.test.ts::legacy payload` passes; the field is optional |

## Questions the description skipped
- <A checklist question that applies, with what you found when you looked>

## Blast radius
- <Traced independently: callers and features outside the diff>

## Questions for the author
1. <The most important one first, specific enough to answer in a sentence>
```
