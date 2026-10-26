#!/usr/bin/env bash
# Fixture test for core's SessionStart hook: the decision-record list, from docs/adr/, from the
# folder .harness/records-source names, or from the copy /records syncs when it names a URL.
# Pipes SessionStart JSON into the hook with CLAUDE_PROJECT_DIR set to a throwaway repo.
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
ok "no records: exit 0" '[ "$code" -eq 0 ]'
lacks "no records: no section" "Decision records"

# docs/adr/ with no source file: the formats teams already use.
A=docs/adr; mkdir -p "$A" tasks .harness
printf '# AD-001: Fetch through the http client\n\nStatus: accepted   \302\267   Date: 2026-10-01\nApplies to: src/api/**\nCheck: a fetch() call outside src/lib/http/\n' > "$A/001-fetch-through-http.md"
printf '# AD-002: Old rule\n\nStatus: superseded by AD-004\n' > "$A/002-old-rule.md"
printf '# AD-003: Maybe later\n\nStatus: proposed\n' > "$A/003-maybe-later.md"
printf '# AD-004: New rule\r\n\r\nStatus: Accepted\r\n' > "$A/004-new-rule.md"
printf '# 5. Record architecture decisions\n\nDate: 2026-01-01\n\n## Status\n\nAccepted\n\n## Context\nStatus: declined\n' > "$A/0005-record-architecture-decisions.md"
printf '# 6. Old tools rule\n\n## Status\n\n*Superseded by [7. x](0007-x.md)*\n' > "$A/0006-old-tools-rule.md"
printf -- '---\nstatus: accepted\ndate: 2026-01-01\n---\n# Use MADR\n' > "$A/007-use-madr.md"
printf '# No status here\n\nWe just do this.\n' > "$A/008-no-status.md"
printf 'Status: accepted\n' > "$A/009-no-title.md"
printf '* **Status:** **Accepted**\n* **Applies to:** **/*.tsx\n# AD-010: Bold fields\n' > "$A/010-bold-fields.md"
printf '* **Status:** **Declined**\n# AD-011: Bold no\n' > "$A/011-bold-no.md"
printf '# Template\nStatus: accepted\n' > "$A/template.md"
printf '# Index of records\n' > "$A/README.md"
printf '# T-1\nStatus: in-progress\n' > tasks/T-1.md && echo tasks/T-1.md > .harness/current-task

out="$(run)"; code=$?
ok "exit 0" '[ "$code" -eq 0 ]'
has "counted, by status" "## Decision records (docs/adr/: 7 accepted, 1 proposed)"
has "our format, with Applies to" "- AD-001: Fetch through the http client (applies to: src/api/**)"
lacks "superseded left out" "AD-002"
has "proposed listed, marked" "- AD-003: Maybe later (proposed)"
has "CRLF file, capitalised status" "- AD-004: New rule"
ok "CR stripped" '! printf "%s\n" "$out" | grep "AD-004" | grep -q "$(printf "\r")"'
has "adr-tools: Status heading, not a later Status line" "- 5. Record architecture decisions"
lacks "adr-tools: superseded left out" "Old tools rule"
has "MADR front matter" "- Use MADR"
has "no status counts as accepted" "- No status here"
has "no title line: the name stands in" "- 009 no title"
has "bold list fields" "- AD-010: Bold fields (applies to: **/*.tsx)"
lacks "declined left out" "AD-011"
lacks "a template isn't a record" "Template"
lacks "a README isn't a record" "Index of records"
has "says never edit them" "Never edit them"
ok "listed before the current task" '[ "$(printf "%s\n" "$out" | grep -n "^## Decision records" | cut -d: -f1)" -lt "$(printf "%s\n" "$out" | grep -n "^## Current task" | cut -d: -f1)" ]'

# A folder named in .harness/records-source wins over docs/adr/.
mkdir -p decisions && printf '# D-1: Snake case columns\nStatus: accepted\n' > decisions/d-1-snake-case.md
echo decisions/ > .harness/records-source
out="$(run)"
has "a named folder" "## Decision records (decisions/: 1 accepted, 0 proposed)"
lacks "a named folder: docs/adr/ not read" "AD-001"

# A URL: the copy /records syncs into .harness/records/.
echo "https://notes.example.com/team/records-db" > .harness/records-source
out="$(run)"
has "a URL, not synced: says so" "The team keeps its decision records at https://notes.example.com/team/records-db; not synced yet: run /records."
has "a URL, not synced: under the heading" "## Decision records"
lacks "a URL: docs/adr/ not read" "AD-001"
R=.harness/records; mkdir -p "$R"
printf 'Source: https://notes.example.com/team/records-db\nSynced: 2026-10-25T10:00:00Z\nD-001 · accepted · One HTTP client · Backend\n' > "$R/index.md"
printf '# D-001: One HTTP client\n\nStatus: accepted\nTags: Backend\nSource: https://notes.example.com/p/1\n\n## Decision\nWe will.\n' > "$R/d-001-one-http-client.md"
printf '# D-002: Snake case columns\n\nStatus: accepted\nTags: Backend, Data\nSource: https://notes.example.com/p/2\n' > "$R/d-002-snake-case-columns.md"
printf '# D-003: Cache keys\n\nStatus: proposed\nTags: Frontend\nSource: https://notes.example.com/p/3\n' > "$R/d-003-cache-keys.md"
printf '# D-004: Retries\n\nStatus: declined\n' > "$R/d-004-retries.md"
printf '# D-005: First try\n\nStatus: superseded\nSuperseded by: D-006\n' > "$R/d-005-first-try.md"
out="$(run)"
has "the synced copy" "## Decision records (.harness/records/: 2 accepted, 1 proposed)"
has "tags shown" "- D-002: Snake case columns [Backend, Data]"
has "proposed, with tags" "- D-003: Cache keys (proposed) [Frontend]"
lacks "declined left out" "D-004"
lacks "superseded left out" "D-005"
lacks "the index isn't a record" "- index"
lacks "fresh copy: no note" "run /records"
touch -t 202001010000 "$R/index.md"
out="$(run)"
has "a stale copy: says so" "last synced more than a week ago: run /records"
has "a stale copy: still listed" "- D-001: One HTTP client [Backend]"
rm -f "$R"/d-00[123]*.md; touch "$R/index.md"
out="$(run)"
lacks "nothing in force, fresh copy: no section" "Decision records"
touch -t 202001010000 "$R/index.md"; out="$(run)"
has "nothing in force, stale copy: still says so" "last synced more than a week ago"

# Budget: many records, long titles.
rm -f "$R"/*.md; touch "$R/index.md"
long="$(i=0; while [ $i -lt 30 ]; do printf 'long title '; i=$((i + 1)); done)"
i=1; while [ $i -le 50 ]; do printf '# D-%03d: r%s %s\nStatus: accepted\n' $i $i "$long" > "$R/d-$(printf %03d $i)-r$i.md"; i=$((i + 1)); done
e="$(i=0; while [ $i -lt 100 ]; do printf '\303\251'; i=$((i + 1)); done)"
printf '# D-000: %s\nStatus: accepted\n' "$e" > "$R/d-000-accents.md"
out="$(run)"
has "many records: all counted" "(.harness/records/: 51 accepted, 0 proposed)"
has "many records: the rest are named" "more in .harness/records/"
ok "many records: within the byte budget" 'n="$(printf "%s\n" "$out" | sed -n "/^## Decision records/,/^## [^D]/p" | grep "^- D-" | LC_ALL=C wc -c)"; [ "$n" -le 3000 ]'
ok "many records: lines cut to 160 bytes" 'l="$(printf "%s\n" "$out" | grep "^- D-001: ")"; [ "$(printf "%s" "$l" | LC_ALL=C wc -c)" -eq 160 ] && [ "${l%...}" != "$l" ]'
ok "a cut title keeps whole UTF-8 characters" 'l="$(printf "%s\n" "$out" | grep "^- D-000: ")"; printf "%s" "$l" | grep -q "^- D-000: éééé" && printf "%s\n" "$l" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1'

if [ "$fails" -gt 0 ]; then echo "core-session-start: $fails of $checks checks failed"; exit 1; fi
echo "core-session-start: $checks checks passed"
