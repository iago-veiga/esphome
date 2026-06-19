#!/usr/bin/env python3
"""Check repository conventions and dependency integrity."""

from __future__ import annotations

from pathlib import Path
import sys

import yaml

from repo_config import (
    AREA,
    DEVICE_BASE,
    DEVICE_NAME,
    FRIENDLY_NAME,
    ROOT,
    SECRET,
    dependencies,
    device_configs,
    includes,
    inventory,
    match_one,
    read,
    relative,
)


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    configs = device_configs()
    names: dict[str, Path] = {}
    all_dependencies: set[Path] = set()

    if not configs:
        errors.append("no device configs found in repository root")

    for config in configs:
        content = read(config)
        device_name = match_one(DEVICE_NAME, content)
        base_matches = DEVICE_BASE.findall(content)

        if not device_name:
            errors.append(f"{config.name}: missing substitutions.device_name")
        else:
            if device_name != config.stem:
                errors.append(
                    f"{config.name}: device_name is {device_name!r}, expected {config.stem!r}"
                )
            if previous := names.get(device_name):
                errors.append(
                    f"{config.name}: duplicate device_name also used by {previous.name}"
                )
            names[device_name] = config

        if not match_one(FRIENDLY_NAME, content):
            errors.append(f"{config.name}: missing esphome.friendly_name")
        if not match_one(AREA, content):
            errors.append(f"{config.name}: missing esphome.area")

        if len(base_matches) != 1:
            errors.append(
                f"{config.name}: expected exactly one device_base include, found {len(base_matches)}"
            )
        elif not (ROOT / base_matches[0]).is_file():
            errors.append(f"{config.name}: missing {base_matches[0]}")

        for dependency in dependencies(config):
            all_dependencies.add(dependency)
            for included in includes(dependency):
                if not included.is_file():
                    errors.append(
                        f"{relative(dependency)}: missing include {included}"
                    )

    inventory_devices = inventory()
    config_names = set(names)
    inventory_names = set(inventory_devices)
    for name in sorted(config_names - inventory_names):
        errors.append(f"inventory/devices.yaml: missing device {name}")
    for name in sorted(inventory_names - config_names):
        errors.append(f"inventory/devices.yaml: unknown device {name}")
    allowed_inventory_keys = {"address", "model", "notes"}
    for name, values in inventory_devices.items():
        if values is not None and not isinstance(values, dict):
            errors.append(f"inventory/devices.yaml: {name} must contain a mapping")
            continue
        unknown = set(values or {}) - allowed_inventory_keys
        if unknown:
            errors.append(
                f"inventory/devices.yaml: {name} has unknown fields {sorted(unknown)}"
            )

    example_secrets = yaml.safe_load(read(ROOT / "secrets.yaml.example")) or {}
    used_secrets: set[str] = set()
    for dependency in all_dependencies:
        used_secrets.update(SECRET.findall(read(dependency)))
    for secret in sorted(used_secrets - set(example_secrets)):
        errors.append(f"secrets.yaml.example: missing secret {secret}")
    for secret in sorted(set(example_secrets) - used_secrets):
        warnings.append(f"secrets.yaml.example: unused secret {secret}")

    reusable = [
        *ROOT.glob("base_devices/*.yaml"),
        *ROOT.glob("common/**/*.yaml"),
    ]
    for path in sorted(reusable):
        if path.resolve() not in all_dependencies:
            warnings.append(f"{relative(path)}: not used by deployable configs")

    for warning in warnings:
        print(f"WARNING: {warning}", file=sys.stderr)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        f"Repository structure OK: {len(configs)} device configs, "
        f"{len(all_dependencies)} dependency files"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
