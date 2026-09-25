#!/usr/bin/env bash
# PreToolUse(Bash): block destructive or irreversible commands. Exit 2 = blocked,
# stderr is shown to Claude. Extend per project with .harness/blocked-commands.txt
# (one extended regex per line) or globally with HARNESS_EXTRA_BLOCK_REGEX.
source "$(dirname "$0")/common.sh"

cmd="$(jget '.tool_input.command')"
[ -n "$cmd" ] || exit 0
c=" $(printf '%s' "$cmd" | tr '\n' ' ' | tr -s ' ') "
root="$(project_dir)"

block() {
  echo "Blocked by harness guard: $1" >&2
  echo "If this is genuinely needed, explain why and ask the user to run it themselves." >&2
  exit 2
}
m() { printf '%s' "$c" | grep -Eq -- "$1"; }

# Recursive delete aimed at root, home, parent dirs, or a bare wildcard
if m '[;&|[:space:]]rm[[:space:]]+(-[^[:space:]]*[rR]|--recursive)' \
   && m '[[:space:]](/|/\*|~|~/|\$HOME|\$HOME/|\.\.|\.\./|\*)([[:space:];&|]|$)'; then
  block "recursive delete of root/home/parent/wildcard path"
fi

# Discarding uncommitted work
m 'git[[:space:]]+reset[[:space:]]+[^;&|]*--hard' && block "git reset --hard discards uncommitted work"
m 'git[[:space:]]+clean[[:space:]]+-[^[:space:]]*f' && block "git clean -f deletes untracked files"
m 'git[[:space:]]+checkout[[:space:]]+(--[[:space:]]+)?\.[[:space:]]' && block "git checkout . discards uncommitted work"

# Pushes
if m 'git[[:space:]]+push'; then
  m '(--force([[:space:]=]|$)|[[:space:]]-f([[:space:]]|$)|[[:space:]]\+[^[:space:]]+)' \
    && block "force push (use --force-with-lease on your own feature branch if you must)"
  prot="${HARNESS_PROTECTED_BRANCHES:-main master production release}"
  cur="$(git -C "$root" branch --show-current 2>/dev/null)"
  for b in $prot; do
    if m "[[:space:]:]${b}([[:space:]]|$)"; then
      if m '--force-with-lease' || is_strict; then block "push to protected branch '$b'"; fi
    fi
    if [ "$cur" = "$b" ] && is_strict; then block "pushing while on protected branch '$b' in $(harness_mode) mode"; fi
  done
fi

# Remote code execution
m '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh([[:space:]]|$)' && block "piping a download straight into a shell"

# Reading secrets through the shell (the file guard covers Read/Edit/Write)
if m '(cat|less|more|head|tail|bat|grep|rg|source|\.)[[:space:]][^;&|]*\.env([.[:space:]]|$)' \
   && ! m '\.env\.(example|sample|template)'; then
  block "reading .env secrets"
fi

# Irreversible external actions: only allowed interactively
if is_strict; then
  m '[[:space:]]sudo[[:space:]]' && block "sudo in $(harness_mode) mode"
  m '(npm|pnpm|yarn|bun)[[:space:]]+(npm[[:space:]]+)?publish|cargo[[:space:]]+publish|eas[[:space:]]+(submit|update)|gh[[:space:]]+release[[:space:]]+create' \
    && block "publishing/releasing in $(harness_mode) mode"
  m '(DROP|TRUNCATE)[[:space:]]+(TABLE|DATABASE|SCHEMA)' && block "destructive SQL in $(harness_mode) mode"
fi

# Project and user extensions
if [ -n "${HARNESS_EXTRA_BLOCK_REGEX:-}" ] && m "$HARNESS_EXTRA_BLOCK_REGEX"; then
  block "matches HARNESS_EXTRA_BLOCK_REGEX"
fi
if [ -f "$root/.harness/blocked-commands.txt" ]; then
  while IFS= read -r re; do
    case "$re" in ''|'#'*) continue ;; esac
    m "$re" && block "matches project rule: $re"
  done < "$root/.harness/blocked-commands.txt"
fi
exit 0
