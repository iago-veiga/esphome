#!/usr/bin/env python3
"""Refresh Device Builder local metadata by nudging its own WS API."""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

from aiohttp import ClientSession, WSMsgType

from repo_config import ROOT, device_configs


DEFAULT_WS_URL = "http://127.0.0.1:6052/ws"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("configs", nargs="*")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--base")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--list-only", action="store_true")
    return parser.parse_args()


def select_configs(args: argparse.Namespace) -> list[str]:
    if args.all and (args.base or args.configs):
        raise SystemExit("ERROR: --all cannot be combined with --base or explicit configs")
    if args.base and args.configs:
      raise SystemExit("ERROR: explicit configs cannot be combined with --base")

    if args.all:
        return sorted(config.name for config in device_configs())

    if args.base:
        import subprocess

        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts" / "affected_configs.py"),
                "--base",
                args.base,
                "--head",
                args.head,
            ],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        return [line for line in result.stdout.splitlines() if line]

    return args.configs


def detect_ws_url() -> str:
    for proc_dir in Path("/proc").iterdir():
        if not proc_dir.name.isdigit():
            continue
        cmdline_path = proc_dir / "cmdline"
        try:
            parts = [part for part in cmdline_path.read_text().split("\0") if part]
        except OSError:
            continue
        if "esphome-device-builder" not in " ".join(parts):
            continue
        for index, part in enumerate(parts):
            if part == "--ingress-port" and index + 1 < len(parts):
                return f"http://127.0.0.1:{parts[index + 1]}/ws"
    return DEFAULT_WS_URL


class WsClient:
    def __init__(self, ws_url: str, token: str) -> None:
        self.ws_url = ws_url
        self.token = token
        self.session: ClientSession | None = None
        self.ws = None
        self.counter = 0

    async def __aenter__(self) -> "WsClient":
        headers = {}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        self.session = ClientSession(headers=headers)
        try:
            self.ws = await self.session.ws_connect(self.ws_url)
            msg = await self.ws.receive_json()
            if "server_version" not in msg or "requires_auth" not in msg:
                raise RuntimeError(f"unexpected first WS message: {msg}")
            if msg.get("requires_auth"):
                raise RuntimeError(
                    "Device Builder requires auth; export DEVICE_BUILDER_TOKEN with a valid bearer token"
                )
        except Exception:
            await self.session.close()
            raise
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        assert self.ws is not None
        assert self.session is not None
        await self.ws.close()
        await self.session.close()

    async def command(self, command: str, **args: object) -> object:
        assert self.ws is not None
        self.counter += 1
        message_id = str(self.counter)
        await self.ws.send_json({"message_id": message_id, "command": command, "args": args})
        while True:
            msg = await self.ws.receive()
            if msg.type != WSMsgType.TEXT:
                raise RuntimeError(f"unexpected WS frame type: {msg.type}")
            payload = msg.json()
            if payload.get("message_id") != message_id:
                continue
            kind = payload.get("type")
            if kind == "result":
                return payload.get("result")
            if kind == "error":
                raise RuntimeError(
                    f"{command} failed: {payload.get('error_code')} {payload.get('details', '')}".strip()
                )


async def refresh_configs(configs: list[str], ws_url: str, token: str) -> tuple[int, int]:
    ok = 0
    fail = 0
    async with WsClient(ws_url, token) as client:
        for config in configs:
            if not (ROOT / config).is_file():
                print(f"[FAIL] {config} (not found in repo)", file=sys.stderr)
                fail += 1
                continue
            try:
                content = await client.command("devices/get_config", configuration=config)
                if not isinstance(content, str):
                    raise RuntimeError("devices/get_config returned non-string content")
                await client.command(
                    "devices/update_config",
                    configuration=config,
                    content=content,
                )
                print(f"[queued] {config}")
                ok += 1
            except Exception as exc:  # noqa: BLE001
                print(f"[FAIL] {config} ({exc})", file=sys.stderr)
                fail += 1
    return ok, fail


async def main_async() -> int:
    args = parse_args()
    configs = select_configs(args)
    if not configs:
        print("No device configs selected")
        return 0

    print(f"Refreshing Device Builder metadata for {len(configs)} config(s):")
    for config in configs:
        print(f"  {config}")

    if args.list_only:
        return 0

    ws_url = os.environ.get("DEVICE_BUILDER_WS_URL") or detect_ws_url()
    token = os.environ.get("DEVICE_BUILDER_TOKEN", "")
    ok, fail = await refresh_configs(configs, ws_url, token)
    print(f"Refresh summary: queued={ok} fail={fail}")
    return 1 if fail else 0


def main() -> int:
    return asyncio.run(main_async())


if __name__ == "__main__":
    raise SystemExit(main())
