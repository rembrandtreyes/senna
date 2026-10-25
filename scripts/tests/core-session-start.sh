#!/usr/bin/env bash
# Fixture test for core's SessionStart hook: the decision-record list from docs/adr/. Pipes
# SessionStart JSON into the hook with CLAUDE_PROJECT_DIR set to a throwaway repo.
# Run by scripts/validate.sh. Exit 0 = all pass, 1 = a check failed.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES \
  GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX GIT_CEILING_DIRECTORIES HARNESS_MODE
hook="$(cd "$(dirname "$0")/../.." && pwd)/plugins/core/hooks/scripts/session-start.sh"
sh_bin=bash; [ -x /bin/bash ] && sh_bin=/bin/bash
tmp="$(mktemp -d "${TMPDIR:-/tmp}/core-session-start-test.XXXXXX")" || exit 1
trap '[ -n "${KEEP:-}" ] || rm -rf "$tmp"' EXIT; [ -n "${KEEP:-}" ] && echo "fixture: $tmp"
fails=0; checks=0

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 HOME="$tmp/home"
r="$tmp/repo"; mkdir -p "$r" "$HOME" && cd "$r" || exit 1
git init -q && git symbolic-ref HEAD refs/heads/main
git config user.email t@example.com; git config user.name t; git config commit.gpgsign false
echo x > a.txt && git add -A && git commit -qm init

run() { printf '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$r" "$sh_bin" "$hook" 2>&1; }
has() { checks=$((checks + 1)); printf '%s\n' "$out" | grep -qF -- "$2" || { echo "FAIL: $1: missing: $2"; fails=$((fails + 1)); }; }
lacks() { checks=$((checks + 1)); printf '%s\n' "$out" | grep -qF -- "$2" && { echo "FAIL: $1: unexpected: $2"; fails=$((fails + 1)); }; }
ok() { checks=$((checks + 1)); eval "$2" || { echo "FAIL: $1"; fails=$((fails + 1)); }; }

out="$(run)"; code=$?
ok "no docs/adr/: exit 0" '[ "$code" -eq 0 ]'
lacks "no docs/adr/: no section" "Decision records"

A=docs/adr; mkdir -p "$A" tasks .harness
printf '# ADR-001: Fetch through the http client\n\nStatus: accepted   \302\267   Date: 2026-10-01\nApplies to: src/api/**\nCheck: a fetch() call outside src/lib/http/\n\n## Decision\nWe will.\n' > "$A/001-fetch-through-http.md"
printf '# ADR-002: Old rule\n\nStatus: superseded by ADR-004\n' > "$A/002-old-rule.md"
printf '# ADR-003: Maybe later\n\nStatus: proposed\n' > "$A/003-maybe-later.md"
printf '# ADR-004: New rule\r\n\r\nStatus: Accepted\r\nCheck: x\r\n' > "$A/004-new-rule.md"
printf '# 5. Record architecture decisions\n\nDate: 2026-01-01\n\n## Status\n\nAccepted\n\n## Context\nStatus: proposed\n' > "$A/0005-record-architecture-decisions.md"
printf '# 6. Old tools rule\n\n## Status\n\n*Superseded by [7. x](0007-x.md)*\n' > "$A/0006-old-tools-rule.md"
printf -- '---\nstatus: accepted\ndate: 2026-01-01\n---\n# Use MADR\n' > "$A/007-use-madr.md"
printf '# No status here\n\nWe just do this.\n' > "$A/008-no-status.md"
printf 'Status: accepted\n' > "$A/009-no-title.md"
printf '* **Status:** **Accepted**\n* **Applies to:** **/*.tsx\n# ADR-010: Bold fields\n' > "$A/010-bold-fields.md"
printf '* **Status:** **Superseded** by ADR-012\n# ADR-011: Bold old\n' > "$A/011-bold-old.md"
printf '# Template\nStatus: accepted\n' > "$A/template.md"
printf '# T-1\nStatus: in-progress\n' > tasks/T-1.md && echo tasks/T-1.md > .harness/current-task

out="$(run)"; code=$?
ok "exit 0" '[ "$code" -eq 0 ]'
has "accepted records counted" "## Decision records (docs/adr/, 7 accepted)"
has "our format, with Applies to" "- ADR-001 Fetch through the http client (applies to: src/api/**)"
lacks "superseded left out" "ADR-002"
lacks "proposed left out" "ADR-003"
has "CRLF file, capitalised status" "- ADR-004 New rule"
ok "CR stripped" '! printf "%s\n" "$out" | grep "ADR-004" | grep -q "$(printf "\r")"'
has "adr-tools format: Status heading" "- ADR-0005 Record architecture decisions"
lacks "adr-tools: superseded left out" "ADR-0006"
has "MADR front matter" "- ADR-007 Use MADR"
has "no status counts as accepted" "- ADR-008 No status here"
has "no title line: the name stands in" "- ADR-009 no title"
has "bold list fields" "- ADR-010 Bold fields (applies to: **/*.tsx)"
lacks "bold superseded left out" "ADR-011"
lacks "a file without a number isn't a record" "Template"
ok "listed before the current task" '[ "$(printf "%s\n" "$out" | grep -n "^## Decision records" | cut -d: -f1)" -lt "$(printf "%s\n" "$out" | grep -n "^## Current task" | cut -d: -f1)" ]'

rm -f "$A"/*.md
long="$(i=0; while [ $i -lt 30 ]; do printf 'long title '; i=$((i + 1)); done)"
i=1; while [ $i -le 30 ]; do printf '# ADR-%03d: r%s %s\nStatus: accepted\n' $i $i "$long" > "$A/$(printf %03d $i)-r$i.md"; i=$((i + 1)); done
e="$(i=0; while [ $i -lt 100 ]; do printf '\303\251'; i=$((i + 1)); done)"
printf '# %s\n' "$e" > "$A/000-accents.md"
out="$(run)"
has "many records: all counted" "(docs/adr/, 31 accepted)"
has "many records: the rest are named" "more in docs/adr/"
ok "many records: within the byte budget" 'n="$(printf "%s\n" "$out" | sed -n "/^## Decision records/,/^## /p" | grep "^- ADR" | wc -c)"; [ "$n" -le 2000 ]'
ok "many records: lines cut to 160 bytes" 'l="$(printf "%s\n" "$out" | grep "^- ADR-001 ")"; [ "$(printf "%s" "$l" | LC_ALL=C wc -c)" -eq 160 ] && [ "${l%...}" != "$l" ]'
ok "a cut title keeps whole UTF-8 characters" 'l="$(printf "%s\n" "$out" | grep "^- ADR-000 ")"; printf "%s" "$l" | grep -q "^- ADR-000 éééé" && printf "%s\n" "$l" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1'

rm -f "$A"/*.md; printf '# ADR-001: x\nStatus: proposed\n' > "$A/001-x.md"
out="$(run)"
lacks "none accepted: no section" "Decision records"

if [ "$fails" -gt 0 ]; then echo "core-session-start: $fails of $checks checks failed"; exit 1; fi
echo "core-session-start: $checks checks passed"
