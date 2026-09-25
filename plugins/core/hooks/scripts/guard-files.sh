#!/usr/bin/env bash
# PreToolUse(Read|Edit|Write|MultiEdit): keep secrets out of context and out of edits.
source "$(dirname "$0")/common.sh"

path="$(jget '.tool_input.file_path')"
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
  .env|.env.*) block "dotenv file" ;;
  *.pem|*.p12|*.pfx|*.keystore|*.jks) block "key/cert material" ;;
  id_rsa*|id_ed25519*|id_ecdsa*) block "SSH key" ;;
  credentials|credentials.json|service-account*.json|.netrc) block "credentials file" ;;
esac
case "$path" in
  */.ssh/*|*/.aws/*|*/.gnupg/*|*/.config/gcloud/*) block "credential directory" ;;
esac
exit 0
