# <Project name>

<One paragraph: what this is, who uses it, and what matters most (latency? correctness? shipping speed?).>

## Stack & layout
- `apps/web` Next.js · `apps/mobile` Expo · `services/api` Go · `crates/engine` Rust   <!-- edit -->
- Contract: `contracts/openapi.yaml` (see api-contracts skill). Regenerate with: `<command>`

## Commands
- Dev: `<command>`   (in worktrees, ports come from `.harness/ports.env`)
- Test: `<command>`
- Lint/typecheck: `<command>`

## Things that will bite you
- <non-obvious facts: migrations, env quirks, flaky areas, generated code locations>

## Out of bounds
- <dirs or systems Claude must not touch without asking>
