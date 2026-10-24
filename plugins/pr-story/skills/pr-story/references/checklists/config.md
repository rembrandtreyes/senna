# Config, infrastructure, and dependencies

- **Missing values.** A new setting that is absent or malformed: does it fail at startup (good)
  or on first use (bad)?
- **Every environment.** Set in preview, staging, production, and CI? Who sets it?
- **Feature flags.** The default, who flips it, and when it gets removed.
- **Dependencies.** For each new or upgraded package: why, who maintains it, its license, what it
  can access, its bundle cost, and whether the lockfile changed only as expected.
- **CI and deploy.** A pipeline, image, or infrastructure change: how was it tested, and how is
  it rolled back?
