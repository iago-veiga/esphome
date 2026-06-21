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
    run --rm -e MODE -e SKIP_CURRENT -e DEVICE -e LOGROOT -e VERSION_CHECK_TIMEOUT \
    --entrypoint /bin/bash esphome /config/scripts/esphome_update_all.sh "$@"
fi

VERSION="$(esphome version | awk '{print $2}')"

MODE="${MODE:-run}"
SKIP_CURRENT="${SKIP_CURRENT:-0}"
ALL=0
DEVICE="${DEVICE:-}"
VERSION_CHECK_TIMEOUT="${VERSION_CHECK_TIMEOUT:-8}"

usage() {
  cat <<'EOF'
Usage: scripts/esphome_update_all.sh [options] [config.yaml ...]

Update configs passed as arguments. Updating every device requires --all.

Options:
  --all                Process all top-level device configs
  --compile-only       Compile without contacting or updating devices
  --status             Compare desired and deployed firmware without updating
  --device ADDRESS     Use explicit address/serial port; requires one config
  --skip-current       Skip devices already running the target ESPHome version
  --force              Always update; compatibility alias for default behavior
  -h, --help           Show this help
EOF
}

configs=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      ALL=1
      ;;
    --compile-only)
      MODE="compile-only"
      ;;
    --status)
      MODE="status"
      ;;
    --device)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --device requires an address or serial port" >&2
        exit 1
      fi
      DEVICE="$2"
      shift
      ;;
    --force)
      SKIP_CURRENT=0
      ;;
    --skip-current)
      SKIP_CURRENT=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      configs+=("$@")
      break
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      configs+=("$1")
      ;;
  esac
  shift
done

if [ "$MODE" != "run" ] && [ "$MODE" != "compile-only" ] && [ "$MODE" != "status" ]; then
  echo "ERROR: MODE must be run, compile-only or status" >&2
  exit 1
fi

if [ "$ALL" = "1" ] && [ "${#configs[@]}" -gt 0 ]; then
  echo "ERROR: --all cannot be combined with explicit configs" >&2
  exit 1
fi

if [ "$ALL" = "1" ] || { [ "$MODE" = "compile-only" ] && [ "${#configs[@]}" -eq 0 ]; }; then
  mapfile -t configs < <(find . -maxdepth 1 -type f -name '*.yaml' \
    ! -name 'secrets.yaml' -printf '%f\n' | sort)
fi

if [ "${#configs[@]}" -eq 0 ]; then
  echo "ERROR: no configs selected; pass config YAMLs or use --all" >&2
  exit 1
fi

if [ -n "$DEVICE" ] && [ "${#configs[@]}" -ne 1 ]; then
  echo "ERROR: --device/DEVICE requires exactly one config" >&2
  exit 1
fi

LOGROOT="${LOGROOT:-$REPO_ROOT/.update-${VERSION}-logs}"
TS="$(date +%Y%m%d-%H%M%S)"
LOGDIR="$LOGROOT/$TS"
mkdir -p "$LOGDIR"

echo "ESPHome $VERSION"
echo "Mode: $MODE"
echo "Skip current version: $SKIP_CURRENT"
echo "Configs: ${#configs[@]}"
echo "Logs: $LOGDIR"

ok_run=0
ok_compile=0
fail_run=0
fail_compile=0
skip_current=0
unknown_version=0
pending=0

for f in "${configs[@]}"; do
  if [ ! -f "$f" ]; then
    echo "[FAIL] $f (not found)" >&2
    if [ "$MODE" = "compile-only" ]; then
      fail_compile=$((fail_compile+1))
    else
      fail_run=$((fail_run+1))
    fi
    continue
  fi

  base="${f%.yaml}"
  config_hash="$(esphome config-hash "$f" | sed 's/^0x//')"
  echo "== $f =="
  echo "[config hash] $config_hash"

  if [ "$MODE" = "compile-only" ]; then
    echo "[compile] $f"
    if esphome compile "$f" \
      >"$LOGDIR/${base}.compile.log" 2>&1; then
      ok_compile=$((ok_compile+1))
    else
      echo "[FAIL compile] $f (see $LOGDIR/${base}.compile.log)" >&2
      tail -n 40 "$LOGDIR/${base}.compile.log" | sed 's/^/  /' >&2
      fail_compile=$((fail_compile+1))
      continue
    fi
  fi

  if [ "$MODE" = "run" ] || [ "$MODE" = "status" ]; then
    device_name="$(sed -n 's/^[[:space:]]*device_name:[[:space:]]*//p' "$f" | head -n 1)"
    if [ -z "$device_name" ]; then
      device_name="$base"
    fi

    target="$DEVICE"
    if [ -z "$target" ]; then
      target="$(python3 scripts/inventory.py --address "$device_name")"
    fi

    if { [ "$SKIP_CURRENT" = "1" ] || [ "$MODE" = "status" ]; } && [[ "$target" != /dev/* ]]; then
      version_error="$LOGDIR/${base}.version.log"
      if current_info="$(timeout --kill-after=2s "${VERSION_CHECK_TIMEOUT}s" \
        python3 scripts/device_info.py "$target" "$device_name" \
        --timeout "$VERSION_CHECK_TIMEOUT" --details 2>"$version_error")"; then
        IFS=$'\t' read -r current_version project_name project_version current_config_hash <<<"$current_info"
        echo "[version] $target reports ESPHome $current_version, config ${current_config_hash:-unknown}"
        if [ "$current_version" = "$VERSION" ] \
          && [ "$current_config_hash" = "$config_hash" ]; then
          echo "[skip current] $f"
          skip_current=$((skip_current+1))
          continue
        fi
        if [ "$MODE" = "status" ]; then
          echo "[pending] $f"
          pending=$((pending+1))
          continue
        fi
      else
        if [ "$MODE" = "status" ]; then
          echo "[unknown] $target (see $version_error)" >&2
        else
          echo "[version unknown] $target; updating anyway (see $version_error)" >&2
        fi
        unknown_version=$((unknown_version+1))
        if [ "$MODE" = "status" ]; then
          continue
        fi
      fi
    fi

    if [ "$MODE" = "status" ]; then
      echo "[unknown] $f (native config hash unavailable)" >&2
      unknown_version=$((unknown_version+1))
      continue
    fi

    echo "[run] $f"
    if esphome run --no-logs --device "$target" "$f" \
      >"$LOGDIR/${base}.run.log" 2>&1; then
      ok_run=$((ok_run+1))
    else
      echo "[FAIL run] $f (see $LOGDIR/${base}.run.log)" >&2
      tail -n 80 "$LOGDIR/${base}.run.log" | sed 's/^/  /' >&2
      fail_run=$((fail_run+1))
    fi
  fi

done

echo "---"
echo "Run:     ok=$ok_run fail=$fail_run"
echo "Compile: ok=$ok_compile fail=$fail_compile"
echo "Skipped current: $skip_current"
echo "Unknown version: $unknown_version"
if [ "$MODE" = "status" ]; then
  echo "Status: current=$skip_current pending=$pending unknown=$unknown_version"
fi

if [ "$fail_compile" -ne 0 ] || [ "$fail_run" -ne 0 ]; then
  exit 2
fi
