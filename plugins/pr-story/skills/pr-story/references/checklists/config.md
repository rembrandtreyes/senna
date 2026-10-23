# Config, infrastructure, and dependencies

- **Missing or wrong values.** What happens if a new environment variable or setting is absent,
  empty, or malformed? Does it fail at startup (good) or on first use (bad)?
- **Per environment.** Is it set in every environment that needs it: local, preview, staging,
  production, CI? Who sets it, and where is that documented?
- **Secrets.** Stored in the secret manager, not in the repo or in plain CI variables.
- **Feature flags.** What's the default? Who flips it, and when does the flag get removed?
- **Dependencies.** For each new or upgraded package: why, its maintenance and license, its size
  (for client bundles), and whether the lockfile changed only as expected.
- **CI and deploy.** Did a pipeline, image, or infrastructure file change? How was it tested,
  and how is it rolled back?
