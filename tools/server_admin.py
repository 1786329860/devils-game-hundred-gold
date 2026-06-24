"""Small SSH helper for deploying the dedicated multiplayer server.

Credentials are intentionally read from environment variables and are never
stored in the project.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import sys

import paramiko


def connect() -> paramiko.SSHClient:
    host = os.environ.get("DEVILS_SSH_HOST", "198.44.178.109")
    user = os.environ.get("DEVILS_SSH_USER", "root")
    password = os.environ.get("DEVILS_SSH_PASSWORD")
    if not password:
        raise SystemExit("DEVILS_SSH_PASSWORD is required")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(host, username=user, password=password, timeout=20)
    return client


def run_command(client: paramiko.SSHClient, command: str) -> int:
    _, stdout, stderr = client.exec_command(command, timeout=300)
    for line in iter(stdout.readline, ""):
        sys.stdout.write(line)
    errors = stderr.read().decode("utf-8", "replace")
    if errors:
        sys.stderr.write(errors)
    return stdout.channel.recv_exit_status()


def upload_tree(client: paramiko.SSHClient, local: pathlib.Path, remote: str) -> None:
    sftp = client.open_sftp()
    run_command(client, f"mkdir -p {remote}")
    for path in local.rglob("*"):
        if "__pycache__" in path.parts or path.suffix == ".pyc":
            continue
        relative = path.relative_to(local).as_posix()
        target = f"{remote}/{relative}"
        if path.is_dir():
            try:
                sftp.mkdir(target)
            except OSError:
                pass
        else:
            sftp.put(str(path), target)
            print(f"uploaded {relative}")
    sftp.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="action", required=True)
    execute = subparsers.add_parser("exec")
    execute.add_argument("command", nargs=argparse.REMAINDER)
    upload = subparsers.add_parser("upload")
    upload.add_argument("local", type=pathlib.Path)
    upload.add_argument("remote")
    args = parser.parse_args()
    client = connect()
    try:
        if args.action == "exec":
            if not args.command:
                raise SystemExit("remote command is required")
            return run_command(client, " ".join(args.command))
        upload_tree(client, args.local.resolve(), args.remote.rstrip("/"))
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
