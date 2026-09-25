---
name: rust
description: Conventions and performance workflow for Rust code. Use whenever writing, reviewing, or debugging Rust, and especially when the work is performance-critical, involves profiling or benchmarks, unsafe code, async runtimes, or FFI with TS/Go services.
---

# Rust conventions

Starting defaults; edit freely.

## Errors
- Libraries: typed errors (`thiserror`). Binaries and app glue: `anyhow` with `.context(...)`.
- No `unwrap()`/`expect()` in library code paths that can fail at runtime. `expect("why this
  can't fail")` is fine for true invariants.

## Style
- Clippy clean. Don't silence a lint without a comment saying why.
- Borrow by default. Clone deliberately, and never in a hot loop without a reason.
- `unsafe` requires a `// SAFETY:` comment stating the invariant, plus a test that exercises it.

## Performance workflow (you're in Rust because it matters)
1. **State the target** in the task file: latency or throughput, and the input size.
2. **Measure before changing anything.** Use `criterion` benches in `benches/`, and always
   benchmark `--release`.
3. **Profile** to find the actual hot spot (`cargo flamegraph`, `perf`, or `samply`). Don't guess.
4. **Change one thing, re-measure**, and record before/after numbers in the task log.
5. Typical wins, in order: algorithmic change, then fewer allocations (reuse buffers,
   `with_capacity`), then less copying (`&str`/slices, `Cow`), then better data layout, then
   parallelism (`rayon`). Reach for `unsafe` last.
6. Check `[profile.release]` settings (`lto`, `codegen-units = 1`) for shipped binaries.

A perf claim without numbers isn't done.

## Async
- One runtime per binary (usually tokio). Don't block in async code; use `spawn_blocking` for CPU
  or blocking I/O.

## Boundaries
- If this crate serves or is called by TS/Go code, the contract lives in one place (see the
  api-contracts skill). Never hand-maintain matching types on both sides.
