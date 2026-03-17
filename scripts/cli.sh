#!/usr/bin/env bash
# CLI entry: version checks (Node, npm, nvm). Run from repo root.
# Usage: bash scripts/cli.sh   or   npm run cli
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/cli/main.sh" "$@"
