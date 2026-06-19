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
    run --rm --entrypoint /bin/bash esphome \
    /config/scripts/esphome_update_affected.sh "$@"
fi

BASE=""
HEAD="HEAD"
MODE="update"

usage() {
  cat <<'EOF'
Usage: scripts/esphome_update_affected.sh --base REF [--head REF] [mode]

Process every device config affected by changes between two Git refs.

Modes:
  --list-only       List affected configs without processing them
  --validate-only   Validate affected configs
  --compile-only    Compile affected configs
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base)
      BASE="${2:-}"
      shift
      ;;
    --head)
      HEAD="${2:-}"
      shift
      ;;
    --compile-only)
      MODE="compile"
      ;;
    --validate-only)
      MODE="validate"
      ;;
    --list-only)
      MODE="list"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ -z "$BASE" ]; then
  echo "ERROR: --base is required" >&2
  exit 1
fi

mapfile -t configs < <(python3 scripts/affected_configs.py --base "$BASE" --head "$HEAD")
if [ "${#configs[@]}" -eq 0 ]; then
  echo "No device configs affected by $BASE...$HEAD"
  exit 0
fi

printf 'Affected configs (%d):\n' "${#configs[@]}"
printf '  %s\n' "${configs[@]}"

if [ "$MODE" = "list" ]; then
  exit 0
fi
if [ "$MODE" = "validate" ]; then
  exec ./scripts/esphome_validate_all.sh "${configs[@]}"
fi
if [ "$MODE" = "compile" ]; then
  exec ./scripts/esphome_update_all.sh --compile-only "${configs[@]}"
fi
exec ./scripts/esphome_update_all.sh "${configs[@]}"
