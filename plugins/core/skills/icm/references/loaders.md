# How Claude Code loads context

Checked against the docs and Claude Code 2.1.319 on 2026-11-09. Loader rules change between
releases: when a finding depends on one, prove it with the probe below and name the version.

Sources:
- https://code.claude.com/docs/en/memory (CLAUDE.md, imports, rules, AGENTS.md, size limits)
- https://code.claude.com/docs/en/context-window#what-survives-compaction
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/sub-agents (what loads at startup)
- https://code.claude.com/docs/en/hooks (InstructionsLoaded, hook output caps)

## At launch (every session)
- `CLAUDE.md`, `.claude/CLAUDE.md`, and `CLAUDE.local.md` in the working directory and every
  folder above it, root first. `CLAUDE.local.md` loads after `CLAUDE.md` in the same folder.
- `@path` imports, expanded with the file that names them: relative to that file, up to 4 hops,
  skipped inside code spans and fenced blocks. They cost the same as pasting the text in.
- `.claude/rules/**/*.md` without `paths:` (same priority as `.claude/CLAUDE.md`), and
  `~/.claude/rules/`.
- Skill descriptions (`description` + `when_to_use`, cut off at 1,536 characters), unless
  `disable-model-invocation: true`.
- Block-level HTML comments in CLAUDE.md are stripped before Claude sees them.
- Docs guidance: under 200 lines per CLAUDE.md; SKILL.md under 500 lines.

## On demand
- A subfolder's `CLAUDE.md` / `CLAUDE.local.md` (and its imports): once Claude reads, writes, or
  edits a file in that folder (a Bash `cat`/`head` of one file counts), every such file on the
  way down loads. Not on `cd`.
- A rule with `paths:` loads when Claude reads, writes, or edits a matching file. Patterns resolve
  from the rule's **base folder**: the folder that contains the rule's `.claude/` folder (for
  `~/.claude/rules/`, the session's working directory).

  | Pattern | Matches |
  |---|---|
  | `**/*.ts` or `*.ts` | `.ts` files anywhere under the base folder |
  | `src/**/*` | everything under `<base>/src/` |
  | `/*.md` | `.md` files directly in the base folder |
  | `src/components/*.tsx` | only directly in `<base>/src/components/` |
  | `src/**/*.{ts,tsx}` | brace expansion works |

- A nested `.claude/rules/` folder loads on demand, by the same base-folder rule.
- `paths:` is the only frontmatter field read. Invalid YAML: the rule loads as if unscoped.
- Size: on-demand files over ~40,000 characters (200K context window; 150,000 on 1M windows for
  current models) arrive truncated, with a note to Read the rest, which Claude may never do.
  Files that load at launch are only skipped past 4 MiB.
- Rules for files in a sibling git worktree load only if the session starts in that worktree.

## AGENTS.md
- Default (`claude-md-or-agents-md`): Claude reads `AGENTS.md` only when there is no `CLAUDE.md`,
  `.claude/CLAUDE.md`, or `CLAUDE.local.md` in the working directory or above it. Then every
  `AGENTS.md` up the tree loads at launch, and a subfolder's `AGENTS.md` loads on demand when
  that folder has no CLAUDE.md files of its own.
- With a root `CLAUDE.md`, Claude reads CLAUDE.md files only. The shared-file pattern is a
  `CLAUDE.md` next to each `AGENTS.md` containing `@AGENTS.md` (Claude-only text below the import).
- **Trap:** `CLAUDE.local.md` counts as a CLAUDE.md. Adding one for personal notes in an
  `AGENTS.md`-only repo makes Claude stop reading `AGENTS.md`. Start it with `@AGENTS.md`, or set
  Project instructions to `claude-md-and-agents-md` in `/config` (user settings only).
- Never read: `AGENTS.local.md`, `AGENTS.override.md`, anything under `.agents/`.
- Symlinking `CLAUDE.md` → `AGENTS.md` works, but the Edit tool won't write through it, and
  Windows clones without `core.symlinks` get a one-line file. Prefer the import.

## Compaction
- Re-injected from disk: the project-root CLAUDE.md, unscoped rules, auto memory.
- Nested CLAUDE.md files and `paths:` rules come back only when a matching file is touched again.
  Anything that must always hold belongs in the root file or an unscoped rule.
- Invoked skills are re-injected, up to 5,000 tokens each and 25,000 in total, oldest dropped
  first. SessionStart hooks with the `compact` matcher run again.

## Subagents
- A subagent gets its own prompt, the delegation prompt, the CLAUDE.md hierarchy and project
  rules (Explore and Plan skip these), and the skills named in its `skills:` frontmatter. It
  doesn't get the parent's conversation or files already read.
- `omitClaudeMd: true` starts it without user, project, and local CLAUDE.md: that's how to give a
  stage subagent only its contract and inputs. Nested CLAUDE.md files and matching scoped rules
  still load when it works in those folders.

## Hooks that add context
- SessionStart and UserPromptSubmit stdout (or `additionalContext`) is added to context;
  PostToolUse only through `hookSpecificOutput.additionalContext`. Each string is capped at
  10,000 characters; past that Claude gets a path and a 2,000-character preview.

## Probe: prove what loads
`InstructionsLoaded` fires for every instruction file that loads, with `file_path` and
`load_reason` (`session_start`, `path_glob_match`, ...). In a scratch folder, never the audited
repo:

```bash
p="$(mktemp -d)"; cd "$p" && git init -q
mkdir -p .claude apps/web/.claude/rules apps/web/src
cp <repo>/apps/web/.claude/rules/*.md apps/web/.claude/rules/   # only the files under test
echo 'export {};' > apps/web/src/Probe.tsx                        # one file each rule should match
cat > .claude/settings.json <<'EOF'
{"hooks":{"InstructionsLoaded":[{"hooks":[{"type":"command","command":"cat >> \"$CLAUDE_PROJECT_DIR/loaded.jsonl\"; echo >> \"$CLAUDE_PROJECT_DIR/loaded.jsonl\""}]}]}}
EOF
echo '# probe' > CLAUDE.md && git add -A && git commit -qm probe
claude -p "Use the Read tool on apps/web/src/Probe.tsx, then reply done" --allowedTools Read < /dev/null
jq -r 'select(.file_path) | "\(.load_reason)  \(.file_path)"' loaded.jsonl
```

Mirror the real folder layout (the base folder is what's being tested). A rule that should load
and doesn't show up in `loaded.jsonl` is proven dead on this version. Delete the scratch folder
afterwards.
