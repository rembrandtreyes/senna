# Network and HTTP

- **Timeouts** on every outbound call, shorter than the caller's own.
- **Retries.** Is the operation idempotent, or does a retry need an idempotency key so it can't
  charge, email, or insert twice?
- **Statuses.** 401, 404, 409, 429, and a body that isn't the expected shape: each handled?
- **Contract.** A changed request or response shape: backwards compatible with clients already
  deployed (mobile apps lag)? Follow the api-contracts skill (ops plugin) if installed.
- **Unbounded lists.** Can a response grow without a page-size cap?
