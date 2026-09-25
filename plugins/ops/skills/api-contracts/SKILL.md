---
name: api-contracts
description: Keep TS clients (Next/Expo) and Go/Rust services in sync through a single API contract. Use whenever work crosses a language boundary, such as adding or changing an endpoint, request/response shape, event payload, or error format, or when a bug looks like a client/server mismatch.
---

# API contracts across languages

The most common silent failure in a polyglot stack is two hand-written copies of the same type
drifting apart. Rule: **one source of truth, generated everywhere else.**

## Pick one contract format per project (record it in the project CLAUDE.md)
- **OpenAPI** for REST/JSON. TS types via `openapi-typescript` (or a generated client). Go via
  `oapi-codegen`. For Rust, either generate the spec from code (e.g. `utoipa`) or generate the
  client from the spec.
- **Protobuf** for RPC and events. `buf` for linting, breaking-change checks, and codegen (Connect
  or gRPC for TS/Go/Rust).

## Workflow for any cross-boundary change
1. **Contract first.** Edit the spec and run the breaking-change check (`buf breaking`, or an OpenAPI
   diff tool). Breaking changes need an explicit decision in the task file.
2. **Regenerate** all sides with the project's codegen command. Never hand-edit generated files;
   they should carry a "generated, do not edit" header.
3. **Implement the server, then the client**, against the generated types.
4. **Add a contract test** where possible: the server's real responses validate against the spec.
5. CI (or the Stop hook override) checks that generated code is up to date: regenerate, then
   `git diff --exit-code`.

## Parallel work
Split cross-boundary features into a contract task (done first, merged first), then server and
client tasks that can run in parallel worktrees against the merged contract.
