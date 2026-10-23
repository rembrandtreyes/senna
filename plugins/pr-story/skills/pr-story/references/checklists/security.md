# Security

Categories follow the [OWASP Code Review Guide](https://owasp.org/www-project-code-review-guide/).
For a full audit, use the security-auditor agent (ops plugin) if it's installed.

- **Authentication and authorization.** Who can call each new or changed entry point? Is that
  checked on the server for this specific resource, not just "logged in"?
- **Input.** Is every input validated where it enters? Could any of it reach a query, a shell, a
  file path, a URL fetch, or a template unescaped (injection, path traversal, SSRF, XSS)?
- **Secrets and personal data.** Are any logged, returned in errors, sent to analytics, or
  shipped in a client bundle? Are new secrets read from the environment, not committed?
- **Sessions and tokens.** How are they created, stored, expired, and revoked? Cookies set with
  `HttpOnly`, `Secure`, and `SameSite`?
- **Access policies.** Row-level security, bucket policies, IAM: updated with the change, and
  tested against the real thing?
- **Dependencies.** Any new package: why it's needed, who maintains it, and what it can access.
