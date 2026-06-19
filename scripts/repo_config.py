#!/usr/bin/env python3
"""Shared repository discovery and dependency helpers."""

from __future__ import annotations

from hashlib import sha256
from pathlib import Path
import re

import yaml


ROOT = Path(__file__).resolve().parent.parent
INCLUDE = re.compile(r"!include\s+([^\s#]+)")
SECRET = re.compile(r"!secret\s+([a-zA-Z0-9_]+)")
DEVICE_NAME = re.compile(r"^\s*device_name:\s*([a-z0-9-]+)\s*$", re.MULTILINE)
DEVICE_BASE = re.compile(
    r"^\s*device_base:\s*!include\s+(base_devices/[a-z0-9-]+\.yaml)\s*$",
    re.MULTILINE,
)
FRIENDLY_NAME = re.compile(r"^\s*friendly_name:\s*(.+?)\s*$", re.MULTILINE)
AREA = re.compile(r"^\s*area:\s*([a-zA-Z0-9_-]+)\s*$", re.MULTILINE)


def device_configs() -> list[Path]:
    return sorted(path for path in ROOT.glob("*.yaml") if path.name != "secrets.yaml")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def includes(path: Path) -> list[Path]:
    return [(path.parent / item).resolve() for item in INCLUDE.findall(read(path))]


def dependencies(path: Path) -> set[Path]:
    found: set[Path] = set()
    pending = [path.resolve()]
    while pending:
        current = pending.pop()
        if current in found or not current.is_file():
            continue
        found.add(current)
        pending.extend(includes(current))
    return found


def relative(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


def fingerprint(path: Path, length: int = 12) -> str:
    digest = sha256()
    for dependency in sorted(dependencies(path), key=relative):
        digest.update(relative(dependency).encode())
        digest.update(b"\0")
        digest.update(dependency.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()[:length]


def match_one(pattern: re.Pattern[str], content: str) -> str:
    match = pattern.search(content)
    return match.group(1).strip() if match else ""


def metadata(path: Path) -> dict[str, str]:
    content = read(path)
    return {
        "config": path.name,
        "device_name": match_one(DEVICE_NAME, content),
        "base": match_one(DEVICE_BASE, content),
        "friendly_name": match_one(FRIENDLY_NAME, content),
        "area": match_one(AREA, content),
        "address": f"{path.stem}.local",
        "fingerprint": fingerprint(path),
    }


def inventory() -> dict[str, dict[str, str]]:
    path = ROOT / "inventory/devices.yaml"
    content = yaml.safe_load(read(path)) or {}
    return content.get("devices", {})
