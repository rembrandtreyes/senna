---
description: Sync the team's decision records (from a Notion database, say) into a read-only local copy that session start lists and the reviewer checks every change against, or show one record. Never writes to the source.
argument-hint: [nothing to sync | a record ID or a few words, to show that record]
---

The project's decision records, the rules the team agreed on. Input: $ARGUMENTS

- **Where they are:** `.harness/records-source`, one line: a URL, or a folder in this repo. When
  it's missing, a `docs/adr/` folder is used if there is one. Otherwise ask the user where the
  team keeps its records, and write the file; it's committed, so teammates get the same source.
- **A folder:** there's nothing to sync. List the records in it.
- **A URL:** run the **records-sync** subagent with it, and pass on its report. It writes the copy
  to `.harness/records/`, which git ignores (the harness keeps `.harness/` out of git).
- **An ID or a few words:** show that record from the copy or the folder, without syncing, and
  give its source link.
- The team owns the records: never create, edit, approve, or comment on one. A change of
  direction is a new record the team writes. If the user asks, draft one for them to take to
  the team.
