# Concurrency and partial failure

- **Check then act.** Is anything read, decided on, and then written, with a gap where another
  request can change it? What closes the gap: a transaction, a lock, a unique constraint?
- **Twice at once.** A double click, a retried job, two workers on one queue message.
- **Halfway.** If it fails midway, what is left half-done, and who cleans it up?
- **Fan-out.** For parallel work: a cap on how many run at once, and what happens to the rest
  when one fails?
