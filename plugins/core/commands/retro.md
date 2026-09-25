---
description: Capture what this session taught us so the harness gets better over time
---

Run a short retro on this session.

1. List every time I corrected you, you had to redo something, a hook blocked or failed you, or
   you discovered something non-obvious about this codebase or stack.
2. For each, write a one-line **rule** phrased as guidance for next time ("Run migrations with
   `make db-migrate`, not `prisma migrate`"), and a scope:
   - `project`: append it to `.harness/learnings.md` as `- YYYY-MM-DD [area] rule`
   - `global`: append it to `~/.claude/harness/learnings.md` (create the file if missing)
3. **Promotion check.** Read the existing learnings. If a rule now appears 2 or more times, or
   caused real damage, propose promoting it:
   - behavior that **must** always happen goes into a **hook** (in the harness repo)
   - how-to knowledge for a stack or workflow goes into a **skill**
   - a project-specific fact goes into the project **CLAUDE.md**

   Draft the exact change, but ask me before editing CLAUDE.md or anything in the harness repo.
4. Keep it short. Skip anything that was a one-off.
