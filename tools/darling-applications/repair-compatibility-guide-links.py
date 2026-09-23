#!/usr/bin/env python3
"""Repair the contribution-guide URL in already published compatibility issues.

The first batch used an upstream branch URL even though the branch lives in the
fork. This command defaults to a read-only preview and journals successful
edits so a rate-limited run can resume without touching completed issues.
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


OLD = "https://github.com/VibeDarling/darling/blob/feature/imported-app-live-scan/tools/darling-applications/CONTRIBUTING-COMPATIBILITY.md"
NEW = "https://github.com/cristim/darling/blob/feature/imported-app-live-scan/tools/darling-applications/CONTRIBUTING-COMPATIBILITY.md"


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".guide-link-state-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def gh_api(method, path, body=None):
    command = ["gh", "api", "--method", method, path]
    if body is not None:
        command += ["--input", "-"]
    result = subprocess.run(command, input=json.dumps(body) if body is not None else None,
                            text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"gh api exited {result.returncode}")
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("state", type=Path, help="compatibility-issue-state.json")
    parser.add_argument("journal", type=Path, help="resume journal for repaired issues")
    parser.add_argument("--repo", default="VibeDarling/darling")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--delay", type=float, default=2.5)
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args()
    state = json.loads(args.state.read_text())
    done = json.loads(args.journal.read_text()) if args.journal.exists() else {}
    pending = [(key, value) for key, value in state.items() if key not in done]
    if args.limit:
        pending = pending[:args.limit]
    print(f"{len(pending)} selected; {len(done)} already repaired", flush=True)
    if not args.publish:
        for key, issue in pending[:10]:
            print(f"{issue['number']}: {key}")
        return
    for key, issue in pending:
        number = issue["number"]
        path = f"repos/{args.repo}/issues/{number}"
        current = gh_api("GET", path)
        body = current.get("body") or ""
        marker = f"<!-- vd-compat-{key} -->"
        if marker not in body:
            # An existing issue can be linked in state without being generated
            # by this publisher. Never rewrite it based solely on its number.
            done[key] = "external issue; no generated marker"
        elif OLD not in body:
            done[key] = "already repaired or guide absent"
        else:
            gh_api("PATCH", path, {"body": body.replace(OLD, NEW)})
            done[key] = "repaired"
            print(f"{number}: repaired", flush=True)
            time.sleep(args.delay)
        save(args.journal, done)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
