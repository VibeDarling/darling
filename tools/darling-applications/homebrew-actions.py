#!/usr/bin/env python3
"""Prefix-confined actions for a Darling Applications viewer.

This is deliberately a backend, not a host package-manager shim: every brew
command is executed as a macOS program through Darling with DPREFIX set to the
user-selected persistent prefix.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import re

DARLING = os.environ.get("DARLING") or shutil.which("darling") or "/usr/local/bin/darling"
DEFAULT_PREFIX = Path.home() / ".darling-apps"


def confined_prefix(value: str) -> Path:
    prefix = Path(value).expanduser().resolve()
    if not prefix.is_dir():
        raise SystemExit(f"Darling prefix does not exist: {prefix}")
    return prefix


def confined_child(prefix: Path, child: Path) -> Path:
    """Resolve a path and reject symlink/junction escapes from the prefix."""
    resolved = child.resolve()
    try:
        resolved.relative_to(prefix)
    except ValueError:
        raise SystemExit(f"path escapes Darling prefix: {child}")
    return resolved


def guest(prefix: Path, argv: list[str], *, timeout: int = 3600) -> int:
    if not argv or argv[0] != "/opt/homebrew/bin/brew":
        raise ValueError("only native /opt/homebrew/bin/brew is permitted")
    brew = confined_child(prefix, prefix / "opt/homebrew/bin/brew")
    if not brew.is_file() or brew.is_symlink():
        raise SystemExit("native Homebrew is not installed in this prefix")
    env = {k: v for k, v in os.environ.items() if not k.startswith("DYLD_")}
    env["DPREFIX"] = str(prefix)
    env["HOMEBREW_PREFIX"] = "/opt/homebrew"
    skip = next((arg for arg in argv if arg.startswith("--mas-skip=")), None)
    if skip:
        env["HOMEBREW_BUNDLE_MAS_SKIP"] = skip.split("=", 1)[1]
        argv = [arg for arg in argv if not arg.startswith("--mas-skip=")]
    return subprocess.run([DARLING, "shell", *argv], env=env, timeout=timeout).returncode


def mas_entries(text: str) -> list[tuple[str, str]]:
    """Extract MAS declarations without evaluating Brewfile Ruby.

    This is a lexical, balanced-span scan: multiline strings/parentheses are
    retained and only the declaration's name/id metadata is read. The source
    remains unchanged and is still parsed by Homebrew for every non-MAS entry.
    """
    found: list[tuple[str, str]] = []
    for match in re.finditer(r"(?m)(?<![A-Za-z0-9_])mas(?:\s+|\s*\()", text):
        start = match.start(); i = match.end(); quote = None; escaped = False; depth = 0
        while i < len(text):
            ch = text[i]
            if quote:
                if escaped: escaped = False
                elif ch == "\\": escaped = True
                elif ch == quote: quote = None
            elif ch in "'\"": quote = ch
            elif ch in "([{": depth += 1
            elif ch in ")]}": depth = max(0, depth - 1)
            elif ch == "\n" and depth == 0:
                previous = text[start:i].rstrip()
                if not previous.endswith(","):
                    break
            i += 1
        span = text[start:i]
        name_match = re.search(r"mas(?:\s+|\s*\()[\'\"]([^\'\"]+)[\'\"]", span, re.S)
        id_match = re.search(r"\bid\s*:\s*['\"]?([0-9]+)", span)
        if not (name_match and id_match):
            raise SystemExit("could not safely extract a MAS declaration; refusing to execute or rewrite the Brewfile")
        found.append((name_match.group(1), id_match.group(1)))
    return found


def install_homebrew(prefix: Path, bootstrap: Path | None) -> int:
    if bootstrap is None:
        raise SystemExit("configure a checksum-verifying native bootstrap before installing Homebrew")
    script = bootstrap.expanduser().resolve()
    trusted = Path(__file__).resolve().parent
    try:
        script.relative_to(trusted)
    except ValueError:
        raise SystemExit(f"bootstrap must be the tracked helper under {trusted}")
    if not script.is_file() or not os.access(script, os.X_OK):
        raise SystemExit(f"bootstrap is not executable: {script}")
    # The bootstrap is a GUEST-side gate: every path it probes is an absolute
    # /opt/homebrew path and its success branch execs the guest brew.  Running it
    # on the host made it inspect the host's filesystem and report the prefix as
    # empty.  Stage the tracked copy into the prefix and run it there, which also
    # refreshes the prefix-local helper the viewer resolves to.
    staged = confined_child(prefix, prefix / "usr/libexec/darling/homebrew-bootstrap")
    staged.parent.mkdir(parents=True, exist_ok=True)
    staged.write_bytes(script.read_bytes())
    staged.chmod(0o755)
    env = {k: v for k, v in os.environ.items() if not k.startswith("DYLD_")}
    env["DPREFIX"] = str(prefix)
    return subprocess.run(
        [DARLING, "shell", "/usr/libexec/darling/homebrew-bootstrap"],
        env=env, timeout=3600,
    ).returncode


def install_brewfile(prefix: Path, brewfile: Path, confirm_mas: bool) -> int:
    source = brewfile.expanduser().resolve(strict=True)
    text = source.read_text(encoding="utf-8")
    mas = mas_entries(text)
    staging = confined_child(prefix, prefix / "Users" / os.environ.get("USER", "darling") / "Library/Application Support/Darling/Brewfiles")
    staging.mkdir(parents=True, exist_ok=True)
    target = confined_child(prefix, staging / (source.name or "Brewfile"))
    # Replace only our staged copy; never modify the user's source Brewfile.
    fd, temporary = tempfile.mkstemp(prefix=".Brewfile-", dir=staging)
    os.close(fd)
    temporary_path = Path(temporary)
    try:
        temporary_path.write_text(text, encoding="utf-8")
        temporary_path.replace(target)
        guest_target = "/" + str(target.relative_to(prefix))
        skip = ",".join(entry_id for _name, entry_id in mas)
        rc = guest(prefix, ["/opt/homebrew/bin/brew", "bundle", "--file", guest_target, "--mas-skip=" + skip])
        if mas:
            print("Skipped MAS entries (App Store unavailable): " + ", ".join(f"{name} [{entry_id}]" for name, entry_id in mas), flush=True)
        if rc:
            print(f"Other Brewfile packages failed with exit status {rc}; MAS skips were not failures", flush=True)
        return rc
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
