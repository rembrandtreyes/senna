#!/usr/bin/env bash
# Fixture test for plugins/core/skills/icm/scripts/icm-audit.sh. Builds throwaway repos that
# trip each check (and near-misses that must not), runs the script under the system bash (3.2 on
# macOS), and checks the findings. Run by scripts/validate.sh. Exit 0 = all pass, 1 = a check failed.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES
script="$(cd "$(dirname "$0")/../.." && pwd)/plugins/core/skills/icm/scripts/icm-audit.sh"
sh_bin=bash; [ -x /bin/bash ] && sh_bin=/bin/bash
tmp="$(mktemp -d "${TMPDIR:-/tmp}/icm-audit-test.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT; [ -n "${KEEP:-}" ] && echo "fixture: $tmp"
fails=0; checks=0
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 LANG=en_US.UTF-8

run() { out="$("$sh_bin" "$script" "$@" 2>&1)"; code=$?; }
has() { checks=$((checks + 1)); printf '%s\n' "$out" | grep -qF -- "$2" || { echo "FAIL: $1: missing: $2"; fails=$((fails + 1)); }; }
lacks() { checks=$((checks + 1)); printf '%s\n' "$out" | grep -qF -- "$2" && { echo "FAIL: $1: unexpected: $2"; fails=$((fails + 1)); }; }
code_is() { checks=$((checks + 1)); [ "$code" -eq "$2" ] || { echo "FAIL: $1: exit $code, expected $2"; fails=$((fails + 1)); }; }
newrepo() { mkdir -p "$1" && cd "$1" && git init -q && git config user.email t@example.com && git config user.name t; }
lines() { i=0; while [ "$i" -lt "$1" ]; do echo "$2 $i"; i=$((i + 1)); done; }
rule() { mkdir -p "$(dirname "$1")"; { echo '---'; printf '%s\n' "$2"; echo '---'; shift 2; printf '%s\n' "$@"; } > "$1"; }

# ---- Repo A: CLAUDE.md mode monorepo -------------------------------------------------------
newrepo "$tmp/a"
mkdir -p docs apps/web/src apps/api apps/huge workflows/01_plan/output workflows/02_build/output
dup='Every handler validates its input with the shared schema before touching the database layer.'
{ echo '@AGENTS.md'; echo 'Routing: see @docs/big.md for the glossary.'; echo 'Also @missing/file.md here.';
  echo 'Mail me@example.com, and use `@scope/pkg` from npm.'; echo '```'; echo '@fenced/ignored.md'; echo '```'; } > CLAUDE.md
{ echo '# Agents'; echo '## Commands'; echo "- $dup"; echo 'Use the old client for now.'; lines 210 'filler line'; } > AGENTS.md
{ echo '# Glossary'; echo '## Heading One'; lines 150 'glossary entry with some words in it'; } > docs/big.md
echo '@AGENTS.md' > apps/web/CLAUDE.md
{ echo '# Web'; echo "- $dup"; } > apps/web/AGENTS.md
echo '# API notes nobody imports' > apps/api/AGENTS.md
lines 1500 'a long on-demand line that pads this nested context file past the limit' > apps/huge/CLAUDE.md
echo 'export const App = 1' > apps/web/src/App.tsx; echo 'export {}' > apps/api/main.ts
echo 'infra notes' > INFRA.md; echo 'readme' > README.md

rule apps/web/.claude/rules/wrong-base.md 'paths:
  - "apps/web/src/**/*.tsx"' '# Wrong base' 'Rule line one about components.' 'Rule line two about props.' 'Rule line three, see [other](other.md).'
mkdir -p apps/admin/src; echo 'export const Admin = 1' > apps/admin/src/Admin.tsx
printf '# Admin\n\nWriting a component? Read .claude/rules/routed.md first.\n' > apps/admin/CLAUDE.md
rule apps/admin/.claude/rules/routed.md 'paths:
  - "apps/admin/src/**/*.tsx"' '# Routed but written from the root'
rule apps/web/.claude/rules/right.md 'paths:
  - "src/**/*.tsx"' '# Right' 'Right line one.' 'Right line two.' 'Right line three, see [right.md](right.md).'
rule .claude/rules/dead.md 'paths:
  - "nothing/**"' '# Dead'
rule .claude/rules/bad-yaml.md 'paths:
  - "src/**/*.ts' '# Bad yaml'
rule .claude/rules/brace.md 'paths:
  - "apps/**/*.{ts,tsx}"' '# Brace'
rule .claude/rules/comma.md 'paths: "apps/web/src/**/*.tsx, nothing/*.x"' '# Comma'
rule .claude/rules/unscoped.md 'description: always on' '# Unscoped rule body'
# Twins for another tool: one identical apart from its link, one that drifted.
rule .cursor/rules/web-right.mdc 'globs: apps/web/src/**/*.tsx' '# Right' 'Right line one.' 'Right line two.' 'Right line three, see [web-right.mdc](web-right.mdc).'
rule .cursor/rules/web-wrong.mdc 'globs: apps/web/src/**/*.tsx' '# Wrong base' 'Rule line one about components.' 'Rule line two about props, changed.' 'Rule line three, see [x](x.mdc).'

mkdir -p .claude/skills/long .claude/skills/nodesc .claude/skills/folded
{ echo '---'; echo 'name: long'; printf 'description: '; lines 160 'trigger words' | tr '\n' ' '; echo; echo '---'; lines 510 'step'; } > .claude/skills/long/SKILL.md
{ echo '---'; echo 'name: nodesc'; echo '---'; echo 'body'; } > .claude/skills/nodesc/SKILL.md
{ echo '---'; echo 'name: folded'; echo 'description: >-'; echo '  Use when folding things,'; echo '  across two lines.'; echo '---'; echo 'body'; } > .claude/skills/folded/SKILL.md

{ echo '# Stage: plan'; echo '## Inputs'; echo '- L3 `../../docs/big.md#Heading One`'; echo '- L3 `./missing.md`'; echo '- L4 `../00_intake/output/brief.md`'; echo '- L3 the `AGENTS.md` of every folder you change'; echo '- L4 the change itself (`git diff`)';
  echo '- L3 `../../docs/big.md#No Such Heading`'; echo '## Process'; echo 'Plan it.'; echo '## Outputs'; echo '- `output/plan.md`'; } > workflows/01_plan/CONTEXT.md
{ echo '# Stage: build'; echo '## Inputs'; echo '- L4 `../01_plan/output/plan.md`'; echo '## Outputs'; echo '- `output/build.md`'; } > workflows/02_build/CONTEXT.md
git add -A && git commit -qm init

run stamp workflows/01_plan/CONTEXT.md; stamp1="$out"
run stamp; code_is "stamp without a file is a usage error" 2
printf '<!-- icm-inputs: %s -->\nplan\n' "$stamp1" > workflows/01_plan/output/plan.md
run stamp workflows/02_build/CONTEXT.md
printf '<!-- icm-inputs: %s -->\nbuild\n' "$out" > workflows/02_build/output/build.md
echo 'plan, edited after build ran' >> workflows/01_plan/output/plan.md   # build is now stale

run "$tmp/a"
code_is "audit exits 0" 0
has "mode" "instructions: CLAUDE.md"
has "launch counts the AGENTS.md import" "CLAUDE.md with imports:"
has "rule base, nothing points to it" "[blocker] rule-base apps/web/.claude/rules/wrong-base.md"
has "unrouted dead rule is as good as deleted" "as good as deleted"
has "rule base, a loaded file points to it" "[should] rule-base apps/admin/.claude/rules/routed.md"
has "routed dead rule names its pointer" "because apps/admin/CLAUDE.md points to it"
lacks "routed dead rule isn't a blocker" "[blocker] rule-base apps/admin"
has "rule base fix" '"apps/web/src/**/*.tsx" -> "src/**/*.tsx" (1 files)'
lacks "rule written from its base" "right.md: paths resolve"
lacks "right rule isn't dead" "rule-dead apps/web/.claude/rules/right.md"
has "dead rule" "[should] rule-dead .claude/rules/dead.md"
has "bad yaml" "[should] rule-frontmatter .claude/rules/bad-yaml.md"
lacks "brace expansion matches" "brace.md"
has "comma string, one pattern empty" "[info] rule-pattern-empty .claude/rules/comma.md: pattern(s) match no files yet: nothing/*.x"
has "unread AGENTS.md" "[blocker] agents-unread apps/api/AGENTS.md"
lacks "imported AGENTS.md is read" "agents-unread apps/web/AGENTS.md"
lacks "root AGENTS.md is imported" "agents-unread AGENTS.md:"
has "launch lines" "[should] launch-lines AGENTS.md: 214 lines"
has "eager import" "[consider] import-eager CLAUDE.md: @docs/big.md"
has "missing import" "[consider] import-missing CLAUDE.md: '@missing/file.md'"
lacks "email isn't an import" "@example.com"
lacks "code span isn't an import" "@scope/pkg"
lacks "fenced code isn't an import" "fenced/ignored.md"
has "on-demand truncation" "[blocker] ondemand-truncated apps/huge/CLAUDE.md"
has "area budget" "[should] area-budget apps/huge"
has "rule overlay on areas" "apps/web  (+ up to ~"
has "duplicate text" "[consider] dup-text"
has "duplicate text names both files" "AGENTS.md, apps/web/AGENTS.md"
has "twin drift" "[consider] twin-drift apps/web/.claude/rules/wrong-base.md: mirrors .cursor/rules/web-wrong.mdc"
lacks "twin differing only in links" "twin-drift apps/web/.claude/rules/right.md"
has "exact twins counted" "1 mirror a Claude rule exactly"
has "long skill description" "[should] skill-description-long .claude/skills/long/SKILL.md"
has "long skill" "[consider] skill-long .claude/skills/long/SKILL.md: 514 lines"
has "skill without description" "[should] skill-no-description .claude/skills/nodesc/SKILL.md"
lacks "folded description parses" "skills/folded"
has "reverify" "[info] reverify AGENTS.md:4"
has "unrouted doc" "[info] unrouted-doc INFRA.md"
lacks "readme isn't flagged" "unrouted-doc README.md"
has "stage input missing" "[blocker] stage-input-missing workflows/01_plan/CONTEXT.md: input './missing.md'"
has "a pending run-time input is info, not a blocker" "[info] stage-input-pending workflows/01_plan/CONTEXT.md: input '../00_intake/output/brief.md'"
lacks "pending input isn't reported missing" "stage-input-missing workflows/01_plan/CONTEXT.md: input '../00_intake"
lacks "prose bare name isn't a path" "input 'AGENTS.md'"
lacks "prose command isn't a path" "input 'git diff'"
has "stage anchor missing" "[should] stage-anchor-missing workflows/01_plan/CONTEXT.md: input '../../docs/big.md#No Such Heading'"
lacks "existing anchor resolves" "#Heading One' names a section"
has "stale stage output" "[should] stage-stale workflows/02_build/output/build.md"
lacks "fresh stage output" "stage-stale workflows/01_plan/output/plan.md"
has "launch budget" "[consider] launch-budget"
has "unscoped rule counted at launch" "unscoped rules in .claude/rules"
# Severity order: every blocker before the first should.
checks=$((checks + 1))
printf '%s\n' "$out" | sed -n '/^## Findings/,$p' | awk '/^\[should\]/{s=1} s&&/^\[blocker\]/{bad=1} END{exit bad}' \
  || { echo "FAIL: findings not ranked"; fails=$((fails + 1)); }

# Budgets come from the environment.
ICM_AREA_BUDGET=100000 run "$tmp/a"
lacks "area budget override" "area-budget"

# ---- Repo B: AGENTS.md-only repo, and the CLAUDE.local.md trap -----------------------------
newrepo "$tmp/b"
mkdir -p apps/x apps/y
echo '# Shared agent notes' > AGENTS.md
echo '# x' > apps/x/AGENTS.md
echo '# y' > apps/y/AGENTS.md; echo 'Claude-only notes for y' > apps/y/CLAUDE.md
git add -A && git commit -qm init
run "$tmp/b"
has "agents mode" "instructions: AGENTS.md (no CLAUDE.md)"
lacks "nested AGENTS.md loads in agents mode" "agents-unread apps/x/AGENTS.md"
has "CLAUDE.md beside AGENTS.md hides it" "[blocker] agents-unread apps/y/AGENTS.md"
has "agents-mode area listed" "apps/x"
lacks "no local file yet" "local-shadows-agents"

echo 'my own notes' > CLAUDE.local.md
run "$tmp/b"
has "local file shadows AGENTS.md" "[blocker] local-shadows-agents CLAUDE.local.md"
has "now nested AGENTS.md is unread too" "[blocker] agents-unread apps/x/AGENTS.md"
printf '@AGENTS.md\nmy own notes\n' > CLAUDE.local.md
run "$tmp/b"
lacks "importing AGENTS.md fixes the shadow" "local-shadows-agents"

# ---- Repo C: not a git work tree -----------------------------------------------------------
mkdir -p "$tmp/c" && cd "$tmp/c" || exit 1
echo '# c' > CLAUDE.md; rule .claude/rules/r.md 'paths:
  - "src/**"' '# r'
run "$tmp/c"
has "no git" "[info] no-git"
code_is "no git still exits 0" 0
run "$tmp/does-not-exist"
code_is "missing folder" 2

if [ "$fails" -gt 0 ]; then echo "icm-audit: $fails of $checks checks failed"; exit 1; fi
echo "icm-audit: $checks checks passed"
