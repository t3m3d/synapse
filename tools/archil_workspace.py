#!/usr/bin/env python3
"""Keep Synapse agent and sandbox files on a durable Archil disk.

Development work increasingly runs on machines that disappear afterwards: CI
runners and sandboxed coding agents. Anything such a run leaves in its own file
system -- staged sources, build logs, Krypton test binaries, scratch notes -- is
gone when the machine is. This helper pins that work to an Archil disk instead.

The disk is a durable workspace. `run` executes a shell command in an Archil
microVM with the disk already mounted as the working directory, so a later run,
from any machine, starts with the files the earlier one wrote. Disks are found
or created by name, which means a replacement runner needs no local state to
reattach to the same workspace. Commands share the SDK's default request
timeout, so `run` is for short workspace tasks rather than a full Gecko build.

Authentication uses an Archil API key (prefix `key-`) read from
ARCHIL_API_KEY. The key is never written, printed, or stored by this tool. A
disk token is a different, per-disk mount credential and is not used here.

Install the SDK once per checkout:

    python3 -m venv .venv
    .venv/bin/pip install archil

Then:

    export ARCHIL_API_KEY=key-...          # never commit this
    tools/archil_workspace.py status
    tools/archil_workspace.py run -- sh -c 'date > last-run'
    tools/archil_workspace.py run -- cat last-run
"""

from __future__ import annotations

import argparse
import os
import shlex
import sys
from typing import NoReturn

try:
    import archil
except ImportError:  # The SDK is optional until an Archil workspace is used.
    archil = None  # type: ignore[assignment]


API_KEY_ENV = "ARCHIL_API_KEY"
REGION_ENV = "ARCHIL_REGION"
DISK_NAME_ENV = "SYNAPSE_ARCHIL_DISK"

DEFAULT_DISK_NAME = "synapse-build-workspace"

# Archil region identifiers, not cloud-provider region names.
REGIONS = (
    "aws-us-east-1",
    "aws-us-west-2",
    "aws-eu-west-1",
    "gcp-us-central1",
)


def fail(message: str) -> NoReturn:
    print(f"archil workspace: {message}", file=sys.stderr)
    raise SystemExit(2)


def api_key() -> str:
    key = os.environ.get(API_KEY_ENV, "").strip()
    if not key:
        fail(
            f"{API_KEY_ENV} is not set; export an Archil API key "
            "(see .env.example) before using the workspace"
        )
    if not key.startswith("key-"):
        fail(
            f"{API_KEY_ENV} does not look like an Archil API key; API keys "
            "start with key- (a disk token is a different credential)"
        )
    return key


def region() -> str:
    value = os.environ.get(REGION_ENV, "").strip()
    if value and value not in REGIONS:
        fail(
            f"{REGION_ENV}={value} is not an Archil region identifier; "
            f"use one of: {', '.join(REGIONS)}"
        )
    return value


def configure() -> None:
    """Point the SDK at the configured account before any disk calls."""
    if archil is None:
        fail(
            "the Archil SDK is not installed; run "
            ".venv/bin/pip install archil and invoke this tool with .venv/bin/python"
        )
    options = {"api_key": api_key()}
    selected_region = region()
    if selected_region:
        options["region"] = selected_region
    try:
        archil.configure(**options)
    except archil.ArchilError as error:
        fail(f"Archil rejected the client configuration: {error}")


def disk_name() -> str:
    configured = os.environ.get(DISK_NAME_ENV, "").strip()
    return configured or DEFAULT_DISK_NAME


def open_disk(name: str) -> "object":
    """Return the named workspace disk, creating it the first time."""
    configure()
    try:
        disks = archil.list_disks()
    except archil.ArchilError as error:
        fail(f"Archil refused the disk listing: {error}")
    for disk in disks:
        if getattr(disk, "name", None) == name:
            try:
                return archil.get_disk(disk.id)
            except archil.ArchilError as error:
                fail(f"Archil refused to open disk {name}: {error}")
    try:
        created = archil.create_disk(name=name)
    except archil.ArchilError as error:
        fail(f"Archil refused to create disk {name}: {error}")
    # create_disk returns a result holding the new disk and its one-time token.
    # The token is a mount credential and is deliberately not stored here.
    return getattr(created, "disk", created)


def describe(disk: "object", name: str) -> str:
    identifier = getattr(disk, "id", name)
    label = getattr(disk, "name", name)
    return f"{label} ({identifier})"


def status(args: argparse.Namespace) -> int:
    name = disk_name()
    disk = open_disk(name)
    selected_region = region() or "SDK default"
    print(f"Archil API key: set ({API_KEY_ENV}, value not shown)")
    print(f"Archil region: {selected_region}")
    print(f"Workspace disk: {describe(disk, name)}")
    print(
        "Files written by `run` stay on this disk between runs; "
        "change it with " + DISK_NAME_ENV + "."
    )
    return 0


def run(args: argparse.Namespace) -> int:
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        fail("run needs a command, for example: run -- sh -c 'date > last-run'")
    # A single argument is already a shell command; several are quoted back
    # together so argument boundaries survive the trip through the disk's shell.
    shell_command = command[0] if len(command) == 1 else shlex.join(command)

    name = disk_name()
    disk = open_disk(name)
    print(f"Workspace disk: {describe(disk, name)}", file=sys.stderr)
    try:
        result = disk.exec(shell_command)
    except archil.ArchilError as error:
        fail(f"Archil refused the command on {name}: {error}")

    stdout = getattr(result, "stdout", "") or ""
    stderr = getattr(result, "stderr", "") or ""
    if stdout:
        print(stdout, end="" if stdout.endswith("\n") else "\n")
    if stderr:
        print(stderr, end="" if stderr.endswith("\n") else "\n", file=sys.stderr)

    exit_code = getattr(result, "exit_code", 0) or 0
    if exit_code != 0:
        print(f"Command exited {exit_code}; its files remain on the disk.", file=sys.stderr)
    return exit_code


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="archil_workspace.py",
        description="Keep Synapse agent/sandbox files on a durable Archil disk.",
    )
    subcommands = parser.add_subparsers(dest="command_name", required=True)

    status_parser = subcommands.add_parser(
        "status", help="show the workspace disk and the credentials in use"
    )
    status_parser.set_defaults(handler=status)

    run_parser = subcommands.add_parser(
        "run", help="run a command with the disk as its working directory"
    )
    run_parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help="command to run; use `--` before it so its flags stay untouched",
    )
    run_parser.set_defaults(handler=run)
    return parser


def main(argv: "list[str] | None" = None) -> int:
    args = build_parser().parse_args(argv)
    return args.handler(args)


if __name__ == "__main__":
    raise SystemExit(main())
