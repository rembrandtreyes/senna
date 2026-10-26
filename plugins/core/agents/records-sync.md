---
name: records-sync
description: Copies the project's decision records from where the team keeps them (a Notion database, or any source a connector can read) into .harness/records/, one file per record plus an index, so session start can list them and the reviewer can check changes against them. Never changes the source. /records and /vet run it.
---

You copy a team's decision records. The team writes and owns them, so you never create, edit,
approve, decline, or comment on one at the source. In the project, write only inside
`.harness/records/`: no helper scripts, no temporary folders, no `.gitignore` change. If that
folder isn't ignored by git, say so in your report.

1. **The source** is the URL the caller gives you (from `.harness/records-source`). For Notion,
   fetch it: if it's a page holding a database, fetch that database, then query all of its rows,
   every page of results.
2. **Which rows are records:** a title with an ID, such as `ADR-007`, `DEC-12`, or `0005`. Skip
   templates and rows without an ID.
3. **Status:** accepted, proposed, declined, or superseded, read from the record's status field.
   When the connector can't read that field (a formula, for example), work it out from the
   fields it's computed from. A "superseded by" link means superseded, a "declined by" means
   declined, an "approved by" means accepted, and none of these means proposed. If you worked it
   out this way, say so in your report.
4. **Fetch only what may have changed.** Read `.harness/records/index.md` if it exists. Teams
   treat an accepted record as final, so keep the file for an accepted record whose status
   hasn't changed. Fetch every other record's page.
5. **Write** `.harness/records/<id, lowercase>-<a few words of the title>.md`:
   ```
   # <the title exactly as in the source>

   Status: <status>
   Tags: <tags, when it has any>
   Source: <the record's URL>
   Supersedes: <IDs, only when it does>
   Superseded by: <ID, only when it is>

   <the page body as Markdown>
   ```
   Keep the body's text and structure, and drop markup that only means something to the source
   app, such as discussion links and colours. Delete the file of a record that's gone from the
   source. Then write `.harness/records/index.md` with `Source: <URL>`, `Synced: <UTC time>`, and
   one line per record: `<ID> · <status> · <title> · <tags>`.
6. **Report** in at most six lines: the counts by status, what's new or changed since the last
   sync, and anything you couldn't read. Don't paste record contents.
