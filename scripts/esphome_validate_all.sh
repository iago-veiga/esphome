#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VENV_DIR="${VENV_DIR:-$REPO_ROOT/.venv-esphome-latest}"
if [ ! -x "$VENV_DIR/bin/esphome" ]; then
  echo "ERROR: ESPHome venv not found at $VENV_DIR" >&2
  echo "Create it with: python3 -m venv .venv-esphome-latest && . .venv-esphome-latest/bin/activate && pip install -U esphome" >&2
  exit 1
fi

. "$VENV_DIR/bin/activate"
VERSION="$(esphome version | awk '{print $2}')"
LOGDIR=".validate-${VERSION}-logs"
mkdir -p "$LOGDIR"

mapfile -t configs < <(ls -1 *.yaml | grep -v '^secrets\.yaml$' | sort)

echo "Validating ${#configs[@]} configs with ESPHome $VERSION"

failed=0
for f in "${configs[@]}"; do
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