# Adapter: vercel (preview deployment with Toolbar comments)

The deck is deployed as a Vercel preview. Reviewers comment on any element with the Vercel Toolbar;
they need access to the owner's Vercel team. Best at a company that already reviews previews on
Vercel.

**Status: written from Vercel's docs (`vercel comments` is in beta), not yet tested against a real
account.** Check each command's output the first time and fix this file if it differs.

**Available when** `vercel --version` works and `vercel whoami` is logged in. Otherwise offer
`static`.

## Publish
All decks share one Vercel project, so each deck gets its own page path (`/<slug>/`) and comments
can be filtered by it.
1. Staging dir: `.harness/publish/vercel/` in the repo (add it to `.gitignore`). Copy
   `specs/<slug>/deck/index.html` to `.harness/publish/vercel/<slug>/index.html`.
2. First time only: ask for the project name (default `review-decks`), then
   `vercel link --yes --project <name>` in the staging dir.
3. `vercel deploy --yes` in the staging dir: a preview deployment (never `--prod`). It prints the
   URL; the deck is at `<url>/<slug>/`.
4. Tell the user who can open it: the project's Deployment Protection decides (by default, members
   of the Vercel team).

## Collect
In the staging dir:
`vercel comments list --json --status all --all-branches --page "/<slug>/*" --limit 100`, and again
with `--next <pagination.nextCursor>` until there's no cursor. For each thread you need the full
text: `vercel comments inspect <id> --json`.
Records: `ref` = thread id, `source: "vercel comment"`, the author's name, the page path and
element as `section`, messages joined as `text`, `kind: null`. Write them to a scratch JSON file for
`feedback.mjs --records`.

## Write back
`vercel comments reply <id> -m "<F-n>: <resolution>"`, and `vercel comments resolve <id>` for items
that are closed. Show the replies and ask first: reviewers get notified.
