#!/usr/bin/env python3
"""Print firmware metadata reported over mDNS, with native API fallback."""

from __future__ import annotations

import argparse
import asyncio
from pathlib import Path
import sys

import yaml
from aioesphomeapi import APIClient
from zeroconf import Zeroconf


SERVICE_TYPE = "_esphomelib._tcp.local."


def read_mdns_info(expected_name: str, timeout: float) -> tuple[str, str, str, str]:
    """Read firmware metadata advertised by ESPHome over mDNS."""
    zeroconf = Zeroconf()
    try:
        service_name = f"{expected_name}.{SERVICE_TYPE}"
        info = zeroconf.get_service_info(
            SERVICE_TYPE, service_name, timeout=int(timeout * 1000)
        )
        if info is None:
            return "", "", "", ""

        def property_value(key: bytes) -> str:
            return info.properties.get(key, b"").decode("utf-8")

        return (
            property_value(b"version"),
            property_value(b"project_name"),
            property_value(b"project_version"),
            property_value(b"config_hash"),
        )
    finally:
        zeroconf.close()


async def read_info(
    address: str, expected_name: str, encryption_key: str, timeout: float
) -> tuple[str, str, str]:
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
        return info.esphome_version, info.project_name, info.project_version
    finally:
        await client.disconnect(force=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("address")
    parser.add_argument("expected_name")
    parser.add_argument("--secrets", default="secrets.yaml")
    parser.add_argument("--timeout", type=float, default=5.0)
    parser.add_argument(
        "--details",
        action="store_true",
        help=(
            "print ESPHome version, project name, project version and native "
            "config hash as TSV"
        ),
    )
    args = parser.parse_args()

    try:
        version, project_name, project_version, config_hash = read_mdns_info(
            args.expected_name, args.timeout
        )
        if not version:
            secrets = yaml.safe_load(Path(args.secrets).read_text(encoding="utf-8"))
            encryption_key = secrets["esphome_api_encryption_key"]
            version, project_name, project_version = asyncio.run(
                read_info(args.address, args.expected_name, encryption_key, args.timeout)
            )
    except Exception as exc:  # Device/network failures must not stop batch updates.
        print(f"{type(exc).__name__}: {exc}", file=sys.stderr)
        return 2

    if not version:
        print("Device returned an empty ESPHome version", file=sys.stderr)
        return 2

    if args.details:
        print(f"{version}\t{project_name}\t{project_version}\t{config_hash}")
    else:
        print(version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
