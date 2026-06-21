#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DEVICE_BUILDER_CONTAINER="${DEVICE_BUILDER_CONTAINER:-addon_5c53de3b_esphome}"
DEVICE_BUILDER_CONFIG_ROOT="${DEVICE_BUILDER_CONFIG_ROOT:-/config/esphome}"
HEAD="HEAD"
BASE=""
ALL=0
LIST_ONLY=0

usage() {
  cat <<'EOF'
Usage: scripts/device_builder_refresh.sh [options] [config.yaml ...]

Refresh ESPHome Device Builder build_info.json metadata by running
"esphome compile --only-generate" inside the Home Assistant add-on container.

Selection:
  --all                Refresh every top-level device config
  --base REF           Refresh configs affected since REF
  --head REF           Compare against REF when using --base (default: HEAD)
  --list-only          Show selected configs without refreshing
  -h, --help           Show this help
EOF
}

configs=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      ALL=1
      ;;
    --base)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --base requires a Git ref" >&2
        exit 1
      fi
      BASE="$2"
      shift
      ;;
    --head)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --head requires a Git ref" >&2
        exit 1
      fi
      HEAD="$2"
      shift
      ;;
    --list-only)
      LIST_ONLY=1
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

if [ "$ALL" = "1" ] && { [ -n "$BASE" ] || [ "${#configs[@]}" -gt 0 ]; }; then
  echo "ERROR: --all cannot be combined with --base or explicit configs" >&2
  exit 1
fi

if [ -n "$BASE" ] && [ "${#configs[@]}" -gt 0 ]; then
  echo "ERROR: explicit configs cannot be combined with --base" >&2
  exit 1
fi

if [ "$ALL" = "1" ]; then
  mapfile -t configs < <(find . -maxdepth 1 -type f -name '*.yaml' \
    ! -name 'secrets.yaml' -printf '%f\n' | sort)
elif [ -n "$BASE" ]; then
  mapfile -t configs < <(python3 scripts/affected_configs.py --base "$BASE" --head "$HEAD")
fi

if [ "${#configs[@]}" -eq 0 ]; then
  echo "No device configs selected"
  exit 0
fi

printf 'Refreshing Device Builder metadata for %d config(s):\n' "${#configs[@]}"
printf '  %s\n' "${configs[@]}"

if [ "$LIST_ONLY" = "1" ]; then
  exit 0
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

LOGDIR="$REPO_ROOT/.dashboard-refresh-logs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOGDIR"
ok=0
fail=0

for config in "${configs[@]}"; do
  if [ ! -f "$config" ]; then
    echo "[FAIL] $config (not found in repo)" >&2
    fail=$((fail + 1))
    continue
  fi

  log_path="$LOGDIR/${config%.yaml}.log"
  config_path="${DEVICE_BUILDER_CONFIG_ROOT}/${config}"
  echo "[generate] $config"
  if docker exec "$DEVICE_BUILDER_CONTAINER" \
    esphome compile --only-generate "$config_path" >"$log_path" 2>&1; then
    ok=$((ok + 1))
  else
    echo "[FAIL] $config (see $log_path)" >&2
    tail -n 40 "$log_path" | sed 's/^/  /' >&2
    fail=$((fail + 1))
  fi
done

echo "Refresh summary: ok=$ok fail=$fail logs=$LOGDIR"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
