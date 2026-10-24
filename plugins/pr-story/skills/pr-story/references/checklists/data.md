# Data and migrations

- **Rollout order.** During deploy, old code runs against the new schema and new code may run
  against the old one. Does each pairing work? A rename or a new NOT NULL column usually needs
  expand, migrate, then contract.
- **Online?** Will it lock a large table or rewrite every row in production? Does a backfill
  run separately, in batches? Does the new index build without blocking writes?
- **Before the backfill.** What do existing rows hold for a new column, and does any code read
  it before the backfill finishes?
- **Destructive.** Is data dropped or overwritten? Is there a backup, and a written way back?
- **Row-level policies** for the new table or column: updated, and tested against the real
  database rather than a mock?
