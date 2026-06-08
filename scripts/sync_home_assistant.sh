#!/bin/sh
set -eu

REPO_ROOT="${REPO_ROOT:-/root/config/esphome}"
BRANCH="${BRANCH:-master}"

cd "$REPO_ROOT"

if [ "$(git branch --show-current)" != "$BRANCH" ]; then
  echo "ERROR: expected branch $BRANCH" >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: tracked local changes prevent automatic sync" >&2
  exit 1
fi

git fetch --quiet origin "$BRANCH"

local_commit="$(git rev-parse HEAD)"
remote_commit="$(git rev-parse "origin/$BRANCH")"

if [ "$local_commit" = "$remote_commit" ]; then
  exit 0
fi

if ! git merge-base --is-ancestor "$local_commit" "$remote_commit"; then
  echo "ERROR: local branch cannot fast-forward to origin/$BRANCH" >&2
  exit 1
fi

git merge --ff-only --quiet "origin/$BRANCH"
echo "Updated $BRANCH: $local_commit -> $remote_commit"
