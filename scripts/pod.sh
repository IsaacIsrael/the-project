#!/usr/bin/env bash
# Run bundle exec pod from repo root with --project-directory=ios (no cd).
# Usage: npm run pod -- install | npm run pod -- update …
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
exec bundle exec pod "$@" --project-directory="$ROOT/ios"
