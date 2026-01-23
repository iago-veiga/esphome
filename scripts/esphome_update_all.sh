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

MODE="${MODE:-run}"
# MODE can be: run | compile-only

LOGROOT="${LOGROOT:-$REPO_ROOT/.update-${VERSION}-logs}"
TS="$(date +%Y%m%d-%H%M%S)"
LOGDIR="$LOGROOT/$TS"
mkdir -p "$LOGDIR"

# If YAMLs are passed as args, use them; otherwise use all top-level configs.
if [ "$#" -gt 0 ]; then
  configs=("$@")
else
  mapfile -t configs < <(ls -1 *.yaml | grep -v '^secrets\.yaml$' | sort)
fi

echo "ESPHome $VERSION"
echo "Mode: $MODE"
echo "Configs: ${#configs[@]}"
echo "Logs: $LOGDIR"

ok_run=0
ok_compile=0
fail_run=0
fail_compile=0

for f in "${configs[@]}"; do
  if [ ! -f "$f" ]; then
    echo "[skip] $f (not found)" >&2
    continue
  fi

  base="${f%.yaml}"
  echo "== $f =="

  if [ "$MODE" = "compile-only" ]; then
    echo "[compile] $f"
    if esphome compile "$f" >"$LOGDIR/${base}.compile.log" 2>&1; then
      ok_compile=$((ok_compile+1))
    else
      echo "[FAIL compile] $f (see $LOGDIR/${base}.compile.log)" >&2
      tail -n 40 "$LOGDIR/${base}.compile.log" | sed 's/^/  /' >&2
      fail_compile=$((fail_compile+1))
      continue
    fi
  fi

  if [ "$MODE" = "run" ]; then
    echo "[run] $f"
    # Optional: override upload target with DEVICE (serial port/IP/hostname). If unset, ESPHome uses defaults (mDNS hostname).
    if [ -n "${DEVICE:-}" ]; then
      if esphome run --no-logs --device "$DEVICE" "$f" >"$LOGDIR/${base}.run.log" 2>&1; then
        ok_run=$((ok_run+1))
      else
        echo "[FAIL run] $f (see $LOGDIR/${base}.run.log)" >&2
        tail -n 80 "$LOGDIR/${base}.run.log" | sed 's/^/  /' >&2
        fail_run=$((fail_run+1))
      fi
    else
      if esphome run --no-logs "$f" >"$LOGDIR/${base}.run.log" 2>&1; then
        ok_run=$((ok_run+1))
      else
        echo "[FAIL run] $f (see $LOGDIR/${base}.run.log)" >&2
        tail -n 80 "$LOGDIR/${base}.run.log" | sed 's/^/  /' >&2
        fail_run=$((fail_run+1))
      fi
    fi
  fi

done

echo "---"
echo "Run:     ok=$ok_run fail=$fail_run"
echo "Compile: ok=$ok_compile fail=$fail_compile"

if [ "$fail_compile" -ne 0 ] || [ "$fail_run" -ne 0 ]; then
  exit 2
fi