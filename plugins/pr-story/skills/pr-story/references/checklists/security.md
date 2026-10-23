# Security

Categories follow the [OWASP Code Review Guide](https://owasp.org/www-project-code-review-guide/).
For a full audit, use the security-auditor agent (ops plugin) if it's installed.

- **Authorization.** Who can call each new or changed entry point? Is it checked on the server
  for this specific resource, not just "logged in"?
- **Input to a sink.** Could any input reach a query, a shell, a file path, a URL fetch, or a
  template unescaped?
- **Leaks.** Secrets or personal data in logs, error responses, analytics, or a client bundle?
- **Tokens and cookies.** How they expire and are revoked; cookies `HttpOnly`, `Secure`,
  `SameSite`.
- **Policies.** Row-level security, bucket policies, IAM: updated with the change, and tested
  against the real thing?
