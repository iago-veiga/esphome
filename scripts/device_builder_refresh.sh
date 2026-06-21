#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DEVICE_BUILDER_CONTAINER="${DEVICE_BUILDER_CONTAINER:-addon_5c53de3b_esphome}"

if [ "${DEVICE_BUILDER_IN_CONTAINER:-0}" = "1" ]; then
  exec python3 /config/esphome/scripts/device_builder_refresh.py "$@"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is required" >&2
  exit 1
fi

if ! docker inspect "$DEVICE_BUILDER_CONTAINER" >/dev/null 2>&1; then
  echo "ERROR: container $DEVICE_BUILDER_CONTAINER not found" >&2
  exit 1
fi

state="$(docker inspect --format '{{.State.Status}}' "$DEVICE_BUILDER_CONTAINER")"
if [ "$state" != "running" ]; then
  echo "ERROR: container $DEVICE_BUILDER_CONTAINER is not running ($state)" >&2
  exit 1
fi

exec docker exec \
  -e DEVICE_BUILDER_IN_CONTAINER=1 \
  -e DEVICE_BUILDER_WS_URL="${DEVICE_BUILDER_WS_URL:-http://127.0.0.1:6052/ws}" \
  -e DEVICE_BUILDER_TOKEN="${DEVICE_BUILDER_TOKEN:-}" \
  "$DEVICE_BUILDER_CONTAINER" \
  python3 /config/esphome/scripts/device_builder_refresh.py "$@"
