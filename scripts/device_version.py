#!/usr/bin/env python3
"""Print ESPHome version reported by a device through its native API."""

from __future__ import annotations

import argparse
import asyncio
from pathlib import Path
import sys

import yaml
from aioesphomeapi import APIClient


async def read_version(
    address: str, expected_name: str, encryption_key: str, timeout: float
) -> str:
    client = APIClient(
        address,
        6053,
        None,
        noise_psk=encryption_key,
        expected_name=expected_name,
        client_info="esphome-repo-version-check",
    )
    try:
        await asyncio.wait_for(
            client.connect(login=True, log_errors=False), timeout=timeout
        )
        info = await asyncio.wait_for(client.device_info(), timeout=timeout)
        return info.esphome_version
    finally:
        await client.disconnect(force=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("address")
    parser.add_argument("expected_name")
    parser.add_argument("--secrets", default="secrets.yaml")
    parser.add_argument("--timeout", type=float, default=5.0)
    args = parser.parse_args()

    try:
        secrets = yaml.safe_load(Path(args.secrets).read_text(encoding="utf-8"))
        encryption_key = secrets["esphome_api_encryption_key"]
        version = asyncio.run(
            read_version(args.address, args.expected_name, encryption_key, args.timeout)
        )
    except Exception as exc:  # Device/network failures must not stop batch updates.
        print(f"{type(exc).__name__}: {exc}", file=sys.stderr)
        return 2

    if not version:
        print("Device returned an empty ESPHome version", file=sys.stderr)
        return 2

    print(version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
