# Concurrency and partial failure

- **Check then act.** Is anything read, decided on, and then written, with a gap where another
  request can change it? Is the gap closed by a transaction, a lock, or a unique constraint?
- **Double execution.** What if this runs twice at once: a double click, a retried job, two
  workers on one queue message?
- **Partial failure.** If it fails halfway, what is left half-done? Can it resume or roll back,
  or does someone fix it by hand?
- **Ordering.** Does it assume events or messages arrive in order? What happens if they don't?
- **Shared state.** Is any mutable state shared across requests, goroutines, or tasks without a
  guard?
- **Fan-out.** For parallel work (`Promise.all`, goroutines, spawned tasks): is there a limit on
  how many run at once, and what happens to the rest when one fails?
