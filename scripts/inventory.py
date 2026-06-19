#!/usr/bin/env python3
"""Print the deployable device inventory derived from repository configs."""

from __future__ import annotations

import argparse
import json

from repo_config import device_configs, inventory, metadata


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--address", metavar="DEVICE")
    args = parser.parse_args()
    overrides = inventory()
    devices = []
    for path in device_configs():
        item = metadata(path)
        item.update(overrides.get(item["device_name"]) or {})
        devices.append(item)
    if args.address:
        device = next(
            (item for item in devices if item["device_name"] == args.address), None
        )
        if device is None:
            parser.error(f"{args.address}: device not found")
        print(device["address"])
        return 0
    if args.json:
        print(json.dumps({"devices": devices}, indent=2, ensure_ascii=False))
        return 0

    headers = ("DEVICE", "AREA", "BASE", "ADDRESS", "FINGERPRINT")
    rows = [
        (
            item["device_name"],
            item["area"],
            item["base"].removeprefix("base_devices/").removesuffix(".yaml"),
            item["address"],
            item["fingerprint"],
        )
        for item in devices
    ]
    widths = [
        max(len(header), *(len(row[index]) for row in rows))
        for index, header in enumerate(headers)
    ]
    print("  ".join(header.ljust(widths[index]) for index, header in enumerate(headers)))
    for row in rows:
        print("  ".join(value.ljust(widths[index]) for index, value in enumerate(row)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
