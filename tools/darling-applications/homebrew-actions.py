#!/usr/bin/env python3
"""Prefix-confined actions for a Darling Applications viewer.

This is deliberately a backend, not a host package-manager shim: every brew
command is executed as a macOS program through Darling with DPREFIX set to the
user-selected persistent prefix.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import re

DARLING = os.environ.get("DARLING", "/usr/local/bin/darling")
DEFAULT_PREFIX = Path.home() / ".darling-apps"


def confined_prefix(value: str) -> Path:
    prefix = Path(value).expanduser().resolve()
    if not prefix.is_dir():
        raise SystemExit(f"Darling prefix does not exist: {prefix}")
    return prefix


def guest(prefix: Path, argv: list[str], *, timeout: int = 3600) -> int:
    if not argv or argv[0] != "/opt/homebrew/bin/brew":
        raise ValueError("only native /opt/homebrew/bin/brew is permitted")
    brew = prefix / "opt/homebrew/bin/brew"
    if not brew.is_file() or brew.is_symlink():
        raise SystemExit("native Homebrew is not installed in this prefix")
    env = {k: v for k, v in os.environ.items() if not k.startswith("DYLD_")}
    env["DPREFIX"] = str(prefix)
    env["HOMEBREW_PREFIX"] = "/opt/homebrew"
    return subprocess.run([DARLING, "shell", *argv], env=env, timeout=timeout).returncode


def install_homebrew(prefix: Path, bootstrap: Path | None) -> int:
    if bootstrap is None:
        raise SystemExit("configure a checksum-verifying native bootstrap before installing Homebrew")
    script = bootstrap.expanduser().resolve()
    if not script.is_file() or not os.access(script, os.X_OK):
        raise SystemExit(f"bootstrap is not executable: {script}")
    # The bootstrap owns artifact verification and atomic placement.  It receives
    # only the prefix, so it cannot accidentally target the host filesystem.
    return subprocess.run([str(script), str(prefix)], timeout=3600).returncode


def install_brewfile(prefix: Path, brewfile: Path, confirm_mas: bool) -> int:
    source = brewfile.expanduser().resolve(strict=True)
    text = source.read_text(encoding="utf-8")
    if re.search(r"(^|\n)\s*mas\s+['\"]", text) and not confirm_mas:
        raise SystemExit("Brewfile contains mas entries; confirm Apple ID/App Store installation explicitly")
    staging = prefix / "Users" / os.environ.get("USER", "darling") / "Library/Application Support/Darling/Brewfiles"
    staging.mkdir(parents=True, exist_ok=True)
    target = staging / (source.name or "Brewfile")
    # Replace only our staged copy; never modify the user's source Brewfile.
    fd, temporary = tempfile.mkstemp(prefix=".Brewfile-", dir=staging)
    os.close(fd)
    temporary_path = Path(temporary)
    try:
        temporary_path.write_text(text, encoding="utf-8")
        temporary_path.replace(target)
        guest_target = "/" + str(target.relative_to(prefix))
        return guest(prefix, ["/opt/homebrew/bin/brew", "bundle", "--file", guest_target])
    finally:
        temporary_path.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("install-homebrew", "install-brewfile"))
    parser.add_argument("--prefix", default=str(DEFAULT_PREFIX))
    parser.add_argument("--bootstrap")
    parser.add_argument("--brewfile")
    parser.add_argument("--confirm-mas", action="store_true")
    args = parser.parse_args()
    prefix = confined_prefix(args.prefix)
    if args.action == "install-homebrew":
        return install_homebrew(prefix, Path(args.bootstrap) if args.bootstrap else None)
    if not args.brewfile:
        parser.error("install-brewfile requires --brewfile")
    return install_brewfile(prefix, Path(args.brewfile), args.confirm_mas)


if __name__ == "__main__":
    raise SystemExit(main())
