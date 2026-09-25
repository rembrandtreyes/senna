#!/usr/bin/env bash
# Example project override: copy to <project>/.harness/checks/ts-stop.sh and chmod +x.
# When present, it REPLACES the lang-ts Stop defaults. Non-zero exit = checks failed,
# and the output is shown to Claude. HARNESS_MODE is set for you (interactive|parallel|auto).
# This example is for an Nx monorepo; swap in Turborepo, Bazel, Gradle, make, etc.
set -e
pnpm nx affected -t typecheck lint
if [ "$HARNESS_MODE" != "interactive" ]; then
  pnpm nx affected -t test
fi
