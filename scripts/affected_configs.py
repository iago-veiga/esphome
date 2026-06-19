#!/usr/bin/env python3
"""List device configs affected by changed repository files."""

from __future__ import annotations

import argparse
import subprocess

from repo_config import ROOT, dependencies, device_configs, relative


def changed_files(base: str, head: str) -> set[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...{head}", "--"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    changed = {line for line in result.stdout.splitlines() if line}
    if head == "HEAD":
        for args in (
            ["git", "diff", "--name-only", "HEAD", "--"],
            ["git", "diff", "--cached", "--name-only", "--"],
            ["git", "ls-files", "--others", "--exclude-standard"],
        ):
            local = subprocess.run(
                args,
                cwd=ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            changed.update(line for line in local.stdout.splitlines() if line)
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", default="HEAD")
    args = parser.parse_args()

    changed = changed_files(args.base, args.head)
    for config in device_configs():
        config_dependencies = {relative(path) for path in dependencies(config)}
        if changed & config_dependencies:
            print(config.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
