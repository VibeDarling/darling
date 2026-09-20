#!/usr/bin/env python3
"""Report whether a live Darling container is already using a prefix.

Lock files only coordinate callers that take them; a container started outside
that protocol holds no lock, so lock state alone never proves a prefix is free.
This inspects the host instead.

Exits 0 when the prefix is free and 1 when a container is live on it, naming
the processes found.
"""
import os, sys
from pathlib import Path

PROC = Path("/proc")


def read(path):
    try:
        return path.read_bytes()
    except (OSError, PermissionError):
        return b""


def process_name(pid_dir):
    # Identify by comm, and fall back to the exe link. Never by cmdline: a
    # process can be named anything there, and mldr rewrites its own argv.
    name = read(pid_dir / "comm").decode(errors="replace").strip()
    if name:
        return name
    try:
        return os.path.basename(os.readlink(pid_dir / "exe"))
    except OSError:
        return ""


def environ_prefix(pid_dir):
    for entry in read(pid_dir / "environ").split(b"\0"):
        if entry.startswith(b"DPREFIX="):
            return entry[len(b"DPREFIX="):].decode(errors="replace")
    return None


def resolve(path):
    try:
        return str(Path(path).resolve())
    except OSError:
        return str(path)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: qa-prefix-busy.py <prefix>")
    target = resolve(sys.argv[1])

    found = []
    unattributed = []
    for pid_dir in PROC.glob("[0-9]*"):
        name = process_name(pid_dir)
        if name not in ("darlingserver", "mldr", "darling"):
            continue

        # The server takes its prefix as the first argument; guest processes
        # carry it in DPREFIX, and their cwd sits inside it.
        candidates = []
        if name == "darlingserver":
            args = read(pid_dir / "cmdline").split(b"\0")
            if len(args) > 1 and args[1]:
                candidates.append(args[1].decode(errors="replace"))
        prefix = environ_prefix(pid_dir)
        if prefix:
            candidates.append(prefix)
        try:
            candidates.append(os.readlink(pid_dir / "cwd"))
        except OSError:
            pass

        if not candidates:
            # No evidence at all: /proc entries for a process owned by another
            # user are unreadable. "Could not attribute" is not "not on this
            # prefix", and silently treating it as the latter would report a
            # free prefix while a container is live.
            unattributed.append(f"  {pid_dir.name} {name}")
        elif any(resolve(c) == target for c in candidates):
            found.append(f"  {pid_dir.name} {name}")

    if found:
        print(f"A Darling container is live on {target}:", file=sys.stderr)
        print("\n".join(sorted(found)), file=sys.stderr)
        return 1
    if unattributed:
        print("Darling processes are running whose prefix could not be determined, "
              f"so {target} cannot be shown to be free:", file=sys.stderr)
        print("\n".join(sorted(unattributed)), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
