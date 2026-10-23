# Data and migrations

- **Reversible?** Is there a down migration, or a written plan to undo this one?
- **Online?** Will it lock a large table, rewrite every row, or time out in production? Does a
  backfill run separately, in batches?
- **Rollout order.** During deploy, old code runs against the new schema and new code may run
  against the old one. Does each pairing work? A rename or a new NOT NULL column usually needs
  expand, migrate, then contract.
- **Defaults and nulls.** What do existing rows get for a new column? Does any code read the
  column before the backfill finishes?
- **Destructive changes.** Is any data dropped or overwritten? Is there a backup or an export?
- **Indexes.** Do the new queries have one? Does a new index build without blocking writes?
- **Access rules.** If the database has row-level policies, were they updated for the new table
  or column, and is that tested against the real database rather than a mock?
