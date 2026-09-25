#!/usr/bin/env bash
# Copy shared/common.sh into every plugin that has hook scripts.
set -euo pipefail
cd "$(dirname "$0")/.."
for d in plugins/*/hooks/scripts; do
  cp shared/common.sh "$d/common.sh"
  echo "synced $d/common.sh"
done
