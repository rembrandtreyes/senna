# Flavours

A flavour changes what the story leads with and how deep it goes. It never removes the
evidence rule. Use one only when asked.

## security
Lead with the entry points the change adds or alters, the trust boundaries they cross, and the
data they touch (personal data, credentials, money). Answer every item in
`checklists/security.md`, even when the tags didn't select it. For a full audit, dispatch the
security-auditor agent (ops plugin) if it's installed, and fold its findings into the
checklist table.

## newcomer
For a reader who doesn't know this area. Before the change, explain in two or three sentences
how this part of the system works, and define each domain term the first time it appears. List
the files to read first, in order. Link the spec or architecture view when one exists.

## risky-bits
Only the "needs careful eyes" bucket, expanded. For each risky spot: what could go wrong, what
guards against it (a test, a type, a check), and how you would notice in production (a log
line, a metric, an error rate). Everything else collapses to one line.

## performance
Name the hot paths the change touches and how their cost changes: complexity, queries per
request (watch for N+1), indexes the new queries need, allocations in loops, payload and bundle
size. Give measured numbers with how they were measured. If nothing was measured, say so and
give the command or benchmark that would measure it.

## api
Contract first: the request and response shapes before and after, whether the change is
breaking, how it's versioned, which clients are affected, and whether the schema or OpenAPI
file changed with it. Follow the api-contracts skill (ops plugin) if it's installed.
