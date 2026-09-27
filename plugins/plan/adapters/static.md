# Adapter: static (any host, feedback through the PR)

The deck is one self-contained file, `deck/index.html`, committed with the spec. Reviewers open it
locally, or anywhere static files are served. Feedback comes back through the spec's pull request.
Works everywhere: no accounts beyond GitHub, and no claude.ai tools.

## Publish
1. Make sure `deck/index.html` is committed on the spec's branch (the gitignore snippet ignores
   only `deck/qa/`).
2. If the branch has a PR (`gh pr view --json number,url,body`), offer to add a **Review deck**
   section to its description. Show the text and ask before editing: it's visible to everyone on
   the repo.
   ~~~
   ## Review deck
   Open specs/<slug>/deck/index.html (check out the branch, or download the raw file) in a browser.
   - Comment on spec.md lines in this PR, as usual.
   - Or use the deck's review panel, then **Export feedback (JSON)** and paste the file's contents
     into a PR comment inside a ```json block.
   ~~~
   With no PR yet, give the user the file path and the same instructions.
3. If the user wants a hosted URL (GitHub Pages, S3, an internal static host), copy the file there
   as they direct. The feedback path stays the PR.

## Collect
`node <plugin>/scripts/feedback.mjs pending specs/<slug> --pr <number>` reads, with `gh`:
line comments on files under the spec's directory (replies folded in), review summaries
(approvals count as `approve`), and conversation comments, expanding any pasted deck export into
its items. Deck exports sent some other way: `--from <file>`.

## Write back
Offer to reply on the PR with each item's F-ID and resolution (one reply per line-comment thread,
one summary comment for the rest). Show the replies and ask first: they're public to the repo.
Never resolve reviewers' threads for them.
