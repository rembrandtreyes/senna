# Templates

Fill in what applies and delete what doesn't, including whole sections, but keep the Verified
line and the footer links. Angle brackets are placeholders. The examples show the level of
specificity to aim for.

## Author: the PR description

```markdown
## TL;DR
<The problem, in one line.>
<The core change, in one line.>
Risk: <low | medium | high>: <why, in one clause>

Verified: `<command>` (<result>), `<command>` (<result>)
Size: <N> changed lines, over the <limit>-line limit: <the split you'd suggest, or why it stays whole (e.g. 300 of them are synced copies)>

## The story
<Two to five sentences: what was wrong or missing, why it matters now, and the one change
everything else hinges on (`path:40-88`).>

Read in this order:
1. **Careful:** `src/invites/create.ts:22-61`: <the change everything depends on, and what could go wrong>
2. **Careful:** `src/invites/routes.ts`: <why it changed, in a clause>
3. **Skim:** <renames, plumbing, generated files>: mechanical

## Decisions
- **<What was chosen>** over <the alternative>: <why, or "reason not recorded">. (<ADR link, if one exists>)

## Checklist
| Question | Answer | Evidence |
|---|---|---|
| What does the user see when the invite email is already a member? | 409, and the form says "already on the team" | `invites.test.ts::rejects existing member` |
| Is a double-submitted invite sent twice? | **Not handled**: two emails go out | none |
| Does an expired invite link still work? | No, 410 | **not verified**: no test; run `curl -i /invites/<expired-id>` |

## Proof
<details><summary>Before and after</summary>

<A request and response, CLI output, or a screenshot path, before and after.>

</details>

## Blast radius
- <Caller, feature, or consumer outside the diff>: <how it could be affected, and whether a test covers it>

Task: <tasks/T-012-...md> · Spec: <specs/<slug>/spec.md> · Closes <#45>
```

The Size line appears only when pr-facts says OVER. Behaviour with no test is a checklist row
marked "not verified", not a separate section.

## Reviewer: the retelling

```markdown
## The story, as the code tells it
<Two to five sentences, written before reading the author's description.>
Size: <N> lines, <how much is mechanical>; <should it have been split, and where>

## Where it differs from the description
- <The description says X; the code does Y (`path:line`).>

## Claims
| Claim | Verdict | Evidence |
|---|---|---|
| "Retries are idempotent" | contradicted | `queue.ts:88` retries without the dedupe key |
| "Covered by tests" | unsupported | no test exercises the 409 path |
| "Old clients keep working" | confirmed | `v1.test.ts::legacy payload` passes; the field is optional |

Also confirmed: <trivial claims, in one line>

## Questions the description skipped
- <A checklist question that applies, with what you found when you looked>

## Blast radius
- <Traced independently: callers and features outside the diff>

## Questions for the author
1. <The most important one first, specific enough to answer in a sentence>
```

With no description and no commit bodies, drop "Where it differs" and "Claims", and title the
last section "Questions".
