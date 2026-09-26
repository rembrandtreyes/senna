---
name: architecture
description: The repo's architecture-as-code model in architecture/*.c4 (LikeC4) - the map of systems, services, stores, external dependencies, and key flows. Use it BEFORE exploring code for cross-service or unfamiliar work ("how does X reach Y", "what calls this", "where does this data live"), UPDATE it in the same change whenever code adds, removes, renames, or rewires a service, store, queue, or external dependency, and BOOTSTRAP it when a repo has none and the user wants one (or runs /architecture).
argument-hint: "[init | update | check]"
---

# Architecture model (LikeC4)

The model lives in `architecture/` at the repo root, and `likec4` is a pinned dev dependency.
It's the fastest way to understand a repo: read it before sending explorers into the code, and
trust it as far as `likec4 validate` and the `link`s let you check it.

## Reading
- Small models: read `architecture/*.c4` directly.
- Larger ones, or graph questions: the LikeC4 MCP server, if the project's `.mcp.json` has it
  (`find-relationship-paths`, `read-element`, `search-element`, `read-view`).
- `npx likec4 start architecture` opens the interactive browser for the user.
If the model and the code disagree, the code wins. Fix the model in the same change and say so.

## Layout (files)
```
architecture/
  spec.c4        element kinds, tags (shared vocabulary)
  model.c4       elements and relationships (split per system when it passes ~300 lines)
  views.c4       index + one view per system + dynamic views for key flows
likec4.config.json at architecture/ root: {"name": "<repo>", "styles": {"defaults": {"relationship": {"line": "solid"}}}}
```
The config line matters: LikeC4 draws every relationship dashed by default, which hides the
difference between sync calls and async ones.

## Conventions
- **Kinds:** `actor` (people and external callers, `shape person`), `system` (a product or an
  external system), `service` (a deployable), `component` (a part inside a service), `store`
  (database, cache, bucket, `shape cylinder`), `queue` (`shape queue`). Declare only kinds you use.
- **Every element** gets a one-line `description` (its responsibility), `technology` where it
  helps, and a `link` to its code (`link ../services/api 'code'`, relative to the .c4 file) so an
  agent can jump from the model to the source. External systems link to their docs.
- **Nesting** mirrors ownership: system → service → component, at most 3 levels.
- **Relationships** are labeled with what flows or what's done, as a verb phrase ("reads limits",
  "POST webhook"). Async and read-only links get `style { line dashed }`.
- **Ids** are camelCase, no hyphens.
- **Views:** `index` (the landscape: systems and actors only), `view <x> of <system>` for each
  system you own (`include *`), and a `dynamic view` for each of the 3 to 6 flows that matter
  most. Dynamic steps are `a -> b 'what happens'`; a response is `b -> a` or `a <- b`.
- **Level of detail:** model what a new engineer needs to draw on a whiteboard, not every
  module. If an element has no relationships, it probably doesn't belong.

## Syntax that validated first time (for reference)
```
specification {
  element actor { style { shape person } }
  element system
  element service
  element store { style { shape cylinder } }
  tag new
}
model {
  web = actor 'Customer app' { description 'Calls the public API' }
  shop = system 'Shop' {
    api = service 'API' { technology 'Go'  description 'Public REST API'  link ../services/api 'code' }
    db = store 'Postgres' { description 'Orders and users' }
  }
  web -> shop.api 'REST calls'
  shop.api -> shop.db 'reads/writes'
  shop.api -> shop.db 'emits events' { style { line dashed } }
}
views {
  view index { include * }
  view shopView of shop { include * }
  dynamic view checkout {
    title 'Checkout'
    web -> shop.api 'POST /orders'
    shop.api -> shop.db 'insert order'
    shop.api -> web '201 Created'
  }
}
```
LikeC4's own agent skill (`skills/likec4-dsl` in the likec4/likec4 GitHub repo) covers the full
DSL: deployments, extend, dynamic view notes, predicates.

## Validate after every edit
`npx likec4 validate architecture` gives line-numbered errors. Fix and re-run until it's clean.
Never leave the model invalid.

## init: bootstrap a model
1. If `likec4` isn't a dev dependency, ask before adding it
   (`npm install --save-dev --save-exact likec4`; create a minimal private `package.json` in a
   repo that has none). Add `architecture/.export/` to `.gitignore`.
2. Map the repo: dispatch **explorer** agents in parallel, one per top-level area (services,
   apps, infra, config, CI). Ask each for: deployables, stores, queues, external systems, who
   calls whom (with file:line), and the main flows.
3. Write `spec.c4`, `model.c4`, `views.c4` following the conventions. Validate until clean.
4. Check it against the code: every `link` resolves (`ls` each path), and every relationship
   has evidence from step 2.
5. Show the user the `index` view as a short list (systems, and what connects to what), plus
   anything you were unsure about, and offer `npx likec4 start architecture`.
6. Offer to add the MCP server to the project's `.mcp.json`:
   `{"mcpServers": {"likec4": {"command": "npx", "args": ["-y", "@likec4/mcp", "--no-watch", "architecture"]}}}`

## update / check
- **update:** after a change that touches architecture, edit the model, validate, and mention
  the model change in the commit or PR description.
- **check:** compare the model against the code (links resolve, no services or stores missing,
  no relationships to code that's gone) and report drift. Don't fix silently; list it.
