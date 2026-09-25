---
name: go
description: Conventions and workflow for Go services, CLIs, and libraries. Use whenever writing, reviewing, testing, or debugging Go code, designing Go APIs or packages, or working with goroutines, channels, contexts, or errors in Go.
---

# Go conventions

Starting defaults; edit freely.

## Errors
- Wrap with context: `fmt.Errorf("load config %q: %w", path, err)`. Check with `errors.Is` and
  `errors.As`.
- Handle an error once: either log it or return it, not both.
- No `panic` for expected failures. Reserve it for programmer errors at init.

## Context and concurrency
- `ctx context.Context` is the first parameter of anything that does I/O or can block. Respect
  cancellation.
- Every goroutine has an owner and a way to stop. Prefer `errgroup` for fan-out with error
  propagation.
- Any change touching goroutines, channels, or shared state gets tests run with `-race`
  (`HARNESS_GO_TEST_FLAGS=-race` makes the Stop hook do it).

## Design
- Accept interfaces, return concrete types. Define interfaces where they're consumed, and keep
  them small.
- Package names are short nouns. Avoid `util`/`common`/`helpers` grab-bags.
- Zero values should be useful. Constructors only when invariants need them.

## Tests
- Table-driven tests with `t.Run(tc.name, ...)`. Use `t.Helper()` in helpers and `t.Cleanup` for
  teardown.
- Use `httptest` for HTTP handlers. Use real dependencies (testcontainers) over deep mocks for DB
  code when the project supports it.

## Services
- In a parallel worktree, listen on `API_PORT` from `.harness/ports.env`.
- If the service's API is consumed by a TS client, change the contract first (see the
  api-contracts skill).
