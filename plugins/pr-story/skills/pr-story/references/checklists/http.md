# Network and HTTP

- **Timeouts.** Does every outbound call have one, and is it shorter than the caller's?
- **Retries.** What is retried, how many times, with what backoff? Is the operation idempotent,
  or does a retry need an idempotency key so it can't charge, email, or insert twice?
- **Status handling.** Are 4xx and 5xx handled differently? What happens on 401, 404, 409, 429,
  and on a body that isn't the expected shape?
- **Rate limits.** Does this call a limited API, or add an endpoint that needs a limit?
- **What the user sees** when the request fails or is slow: a message, a retry, a spinner that
  never ends?
- **Contract.** Did a request or response shape change? Is it backwards compatible with clients
  already deployed (mobile apps lag)? Follow the api-contracts skill (ops plugin) if installed.
- **Pagination and size.** Can a list grow without bound? Is there a page size cap?
