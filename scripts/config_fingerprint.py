#!/usr/bin/env python3
"""Print the repository-content fingerprint for a device config."""

from __future__ import annotations

import argparse
from pathlib import Path

from repo_config import ROOT, fingerprint


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config")
    args = parser.parse_args()
    path = (ROOT / args.config).resolve()
    if not path.is_file():
        parser.error(f"{args.config}: config not found")
    print(fingerprint(path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
