# Adapter: artifact (claude.ai)

The deck becomes a private claude.ai artifact. Reviewers post feedback in the deck (stored in the
artifact's `db`), comment on any element (claude.ai comments), and decide open questions. Best when
reviewers have claude.ai accounts in the owner's organization.

**Available when** the `Artifact` and `ArtifactData` tools exist in this session (a claude.ai
login). On API-key auth they may be missing: say so and offer `static`.

## Publish
1. Read `deck/index.html` in full (the Artifact tool requires reading a file Claude didn't write
   before publishing it).
2. Publish with the Artifact tool:
   - `file_path`: `specs/<slug>/deck/index.html`
   - `capabilities`: `{"db": {}, "comments": {}, "user": {"scopes": ["profile"]}, "downloads": true}`
     (the page's feedback list, comment anchors, reviewer names, and Export button)
   - first publish: `icon: "review"` and a one-sentence `description` (the spec's ask)
   - republish: `url` from `deck/publish.json`, and no `icon` or `capabilities` (both carry
     over). The db carries over too, and each item records the `specVersion` it was written on.
3. Check it once: `ArtifactData` `list` on the `feedback` collection returns without an error.
4. Tell the user: the artifact is private; declaring `db` makes it organization-internal, so they
   share it from claude.ai with reviewers in their organization (Contributor access to post).
   If the publish result confirms a watch, new comments sent to Claude arrive in this session.

## Collect
- **Deck feedback:** `ArtifactData` `list` on `feedback` (page through all of it) and on
  `decisions`. Resolve every `author` / `by` id with `ArtifactData` `profiles`; the ids are opaque.
  Records: `ref` = the doc id (for decisions, `decision-<questionId>-<updatedAt digits, 12>`),
  `source: "artifact db"`, `section: "deck:<section>"`, and `kind`, `text`, `specVersion`,
  `createdAt`, `status` from the doc.
- **Comment threads:** `ArtifactComments` `read`. One record per thread: `ref` = thread id,
  `source: "artifact comment"`, the anchor's element or section as `section`, the first message
  as `text` with replies appended, `kind: null` (you classify it).
- Write the records to a scratch JSON file and pass it to `feedback.mjs --records`.

## Write back
- Status: for each item whose ledger status changed, `ArtifactData` `update` on
  `feedback/<ref>` with `{status, resolution, ledgerId: "F-n"}`, using `if_version` from the
  read. Use one `batch` when there are several. Reviewers see the new status in the deck.
- Comment threads: `reply` and `resolve` work only on threads a writer sent to Claude. List the
  other threads for the owner to close by hand.
