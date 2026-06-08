#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [ "${ESPHOME_CONTAINER:-0}" != "1" ]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is required" >&2
    exit 1
  fi
  exec docker compose -f .docker/compose.yaml --project-directory "$REPO_ROOT" \
    run --rm --entrypoint /bin/bash esphome /config/scripts/esphome_validate_all.sh "$@"
fi

VERSION="$(esphome version | awk '{print $2}')"
LOGDIR=".validate-${VERSION}-logs"
mkdir -p "$LOGDIR"

if [ "$#" -gt 0 ]; then
  configs=("$@")
else
  mapfile -t configs < <(find . -maxdepth 1 -type f -name '*.yaml' \
    ! -name 'secrets.yaml' -printf '%f\n' | sort)
fi

echo "Validating ${#configs[@]} configs with ESPHome $VERSION"

failed=0
for f in "${configs[@]}"; do
  if [ ! -f "$f" ]; then
    echo "[FAIL] $f does not exist" >&2
    failed=1
    continue
  fi

  echo "[config] $f"
  if ! esphome config "$f" >"$LOGDIR/${f%.yaml}.log" 2>&1; then
    echo "[FAIL] $f (see $LOGDIR/${f%.yaml}.log)" >&2
    tail -n 40 "$LOGDIR/${f%.yaml}.log" | sed 's/^/  /' >&2
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "One or more configs failed under ESPHome $VERSION" >&2
  exit 1
fi

echo "All configs OK under ESPHome $VERSION"
