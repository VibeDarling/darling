#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path


CANONICAL = "https://github.com/VibeDarling/darling.git"


def checkout(source):
    def git(*arguments):
        return subprocess.run(["git", "-C", str(source), *arguments],
                              capture_output=True)

    original = git("config", "--local", "--null", "--get-all", "remote.origin.url")
    origins = original.stdout.split(b"\0")
    if original.returncode or len(origins) != 2 or origins[-1] or not origins[0]:
        raise RuntimeError("requires exactly one configured origin URL")
    cached = git("config", "--local", "--get-regexp", r"^submodule\..*\.url$")
    if cached.returncode != 1:
        raise RuntimeError("requires fresh checkout without initialized submodule URLs")
    changed = git("remote", "set-url", "origin", CANONICAL)
    if changed.returncode:
        raise RuntimeError("cannot set canonical origin")
    status = None
    try:
        # Same flags as actions/checkout@v4 (shallow, fetch-depth 1). Output is
        # inherited so a failure names the module and the git error.
        result = subprocess.run(["git", "-C", str(source), "-c", "protocol.version=2",
                                 "submodule", "update", "--init", "--force", "--depth=1",
                                 "--recursive"])
        status = result.returncode
        return status
    finally:
        restored = git("remote", "set-url", "origin", os.fsdecode(origins[0]))
        if restored.returncode:
            raise RuntimeError(f"cannot restore original origin; checkout exit status: {status}")


def main():
    try:
        status = checkout(Path.cwd())
    except RuntimeError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    if status:
        print(f"error: recursive submodule checkout failed with exit status {status}", file=sys.stderr)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
