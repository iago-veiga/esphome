#!/usr/bin/env python3
"""Check repository conventions without parsing ESPHome-specific YAML tags."""

from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent.parent
DEVICE_NAME = re.compile(r"^\s*device_name:\s*([a-z0-9-]+)\s*$", re.MULTILINE)
DEVICE_BASE = re.compile(
    r"^\s*device_base:\s*!include\s+(base_devices/[a-z0-9-]+\.yaml)\s*$",
    re.MULTILINE,
)


def main() -> int:
    errors: list[str] = []
    configs = sorted(
        path for path in ROOT.glob("*.yaml") if path.name != "secrets.yaml"
    )

    if not configs:
        errors.append("no device configs found in repository root")

    names: dict[str, Path] = {}
    for config in configs:
        content = config.read_text(encoding="utf-8")
        name_match = DEVICE_NAME.search(content)
        base_matches = DEVICE_BASE.findall(content)

        if name_match is None:
            errors.append(f"{config.name}: missing substitutions.device_name")
        else:
            device_name = name_match.group(1)
            if device_name != config.stem:
                errors.append(
                    f"{config.name}: device_name is {device_name!r}, expected {config.stem!r}"
                )
            if previous := names.get(device_name):
                errors.append(
                    f"{config.name}: duplicate device_name also used by {previous.name}"
                )
            names[device_name] = config

        if len(base_matches) != 1:
            errors.append(
                f"{config.name}: expected exactly one device_base include, found {len(base_matches)}"
            )
        elif not (ROOT / base_matches[0]).is_file():
            errors.append(f"{config.name}: missing {base_matches[0]}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"Repository structure OK: {len(configs)} device configs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
