#!/usr/bin/env python3
"""Publish reviewed compatibility issue drafts, with an atomic resume journal.

Default mode is read-only. --publish performs GitHub writes with the caller's
authenticated gh CLI. Re-running skips issue keys already in the journal.
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".issue-state-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write("\n")
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def create(repo, title, body):
    command = ["gh", "api", "--method", "POST", f"repos/{repo}/issues", "--input", "-"]
    for attempt in range(4):
        result = subprocess.run(command, input=json.dumps({"title": title, "body": body}),
                                text=True, capture_output=True)
        if result.returncode == 0:
            return json.loads(result.stdout)
        error = result.stderr.lower()
        # GitHub's secondary creation limit needs a cooldown, not rapid retries.
        if "secondary rate limit" in error or "temporarily blocked from content creation" in error:
            raise RuntimeError(result.stderr.strip())
        if attempt == 3 or not any(value in error for value in ("temporarily unavailable", "502", "503")):
            raise RuntimeError(result.stderr.strip() or f"gh api exited {result.returncode}")
        time.sleep(min(60, 5 * 2 ** attempt))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("drafts", type=Path)
    parser.add_argument("state", type=Path)
    parser.add_argument("--repo", default="VibeDarling/darling")
    parser.add_argument("--kind", choices=("app", "lib", "all"), default="all")
    parser.add_argument("--key", help="publish one exact issue key from index.json")
    parser.add_argument("--limit", type=int, default=0, help="maximum new issues this run; 0 means all")
    parser.add_argument("--delay", type=float, default=1.5, help="seconds to wait after each created issue")
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args()
    index = json.loads((args.drafts / "index.json").read_text())
    state = json.loads(args.state.read_text()) if args.state.exists() else {}
    pending = [item for item in index if item["key"] not in state and
               (not args.key or item["key"] == args.key) and
               (args.kind == "all" or item["key"].startswith(args.kind + ":"))]
    if args.limit:
        pending = pending[:args.limit]
    print(f"{len(pending)} selected; {len(state)} already recorded; target {args.repo}", flush=True)
    if not args.publish:
        for item in pending[:10]:
            print(item["title"])
        return
    for item in pending:
        body = (args.drafts / item["body_file"]).read_text()
        if len(body) > 65000:
            raise RuntimeError(f"issue body exceeds GitHub limit: {item['title']}")
        created = create(args.repo, item["title"], body)
        state[item["key"]] = {"number": created["number"], "url": created["html_url"],
                              "title": item["title"], "body_file": item["body_file"]}
        save(args.state, state)
        print(f"{created['number']}: {item['title']}", flush=True)
        time.sleep(args.delay)
    print(f"Published {len(pending)} issues; journal contains {len(state)} entries", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
