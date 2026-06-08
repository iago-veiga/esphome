#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

exec docker compose -f .docker/compose.yaml --project-directory "$REPO_ROOT" \
  run --rm esphome "$@"
