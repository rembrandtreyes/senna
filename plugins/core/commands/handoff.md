---
description: Write a handoff so the next session (or a teammate) can resume instantly
---

Write `.harness/handoff.md` (overwrite it) with exactly these sections, as tersely as possible:

- **Goal:** what we're trying to achieve, plus the task file path.
- **State:** what works now, and what's verified versus only assumed.
- **Done this session:** the key changes, with files.
- **Next steps:** an ordered list; the first item should be startable immediately.
- **Dead ends:** what we tried that didn't work, and why. This matters most.
- **Open questions:** decisions that need me.

The next session loads this automatically through the SessionStart hook.
