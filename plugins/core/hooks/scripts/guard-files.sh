#!/usr/bin/env bash
# PreToolUse(Read|Edit|Write|MultiEdit|Grep): keep secrets out of context and out of edits.
source "$(dirname "$0")/common.sh"

# Grep takes a `path` (file or directory) and an optional `glob`; the rest take `file_path`.
path="$(jget '.tool_input.file_path')"
[ -n "$path" ] || path="$(jget '.tool_input.path')"
glob="$(jget '.tool_input.glob')"
case "$glob" in
  *.env.example*|*.env.sample*|*.env.template*) ;;
  *.env*) path="${path:-.}/$glob" ;;  # a glob aimed at dotenv files is judged like one
esac
[ -n "$path" ] || exit 0
base="$(basename "$path")"

block() {
  echo "Blocked by harness guard: '$path' looks like a secret ($1)." >&2
  echo "Ask the user for the specific non-secret value you need, or use the .example file." >&2
  exit 2
}

case "$base" in
  .env.example|.env.sample|.env.template|*.example|*.sample) exit 0 ;;
esac
case "$base" in
  .env|.env.*|.env\*|*'*'.env*) block "dotenv file" ;;
  *.pem|*.p12|*.pfx|*.keystore|*.jks) block "key/cert material" ;;
  id_rsa*|id_ed25519*|id_ecdsa*) block "SSH key" ;;
  credentials|credentials.json|service-account*.json|.netrc) block "credentials file" ;;
esac
case "$path" in
  */.ssh|*/.ssh/*|*/.aws|*/.aws/*|*/.gnupg|*/.gnupg/*|*/.config/gcloud|*/.config/gcloud/*)
    block "credential directory" ;;
esac
exit 0
