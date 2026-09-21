#!/usr/bin/env python3
"""
Check open pull requests across all VibeDarling submodules.
Uses GitHub CLI (`gh`) to query the GitHub API efficiently.
"""

import sys
import os
import re
import json
import subprocess
import argparse
from pathlib import Path


def get_repo_root():
    try:
        res = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return Path(res.stdout.strip())
    except subprocess.CalledProcessError:
        return Path.cwd()


def parse_gitmodules(repo_root):
    gitmodules_path = repo_root / ".gitmodules"
    if not gitmodules_path.is_file():
        return {}

    submodules = {}  # repo_name -> list of paths
    current_path = None
    current_url = None

    with open(gitmodules_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            m_path = re.match(r"^path\s*=\s*(.+)$", line)
            if m_path:
                current_path = m_path.group(1).strip()
            m_url = re.match(r"^url\s*=\s*(.+)$", line)
            if m_url:
                current_url = m_url.group(1).strip()
                # Resolve relative URL like ../darling-xnu.git or full URL
                repo_name = os.path.basename(current_url)
                if repo_name.endswith(".git"):
                    repo_name = repo_name[:-4]
                if current_path:
                    submodules.setdefault(repo_name.lower(), []).append(current_path)
                current_path = None
                current_url = None

    return submodules


def fetch_open_prs(owner="VibeDarling"):
    cmd = [
        "gh", "search", "prs",
        "--owner", owner,
        "--state", "open",
        "--limit", "100",
        "--json", "repository,number,title,author,url,isDraft,createdAt"
    ]
    try:
        res = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return json.loads(res.stdout)
    except FileNotFoundError:
        print("Error: 'gh' (GitHub CLI) is not installed or not in PATH.", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error running gh search: {e.stderr}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Check open pull requests for VibeDarling submodules")
    parser.add_argument("--repo", "-r", help="Filter by specific repository name (e.g. darling-xnu)")
    parser.add_argument("--json", action="store_true", help="Output raw JSON results")
    parser.add_argument("--include-all", "-a", action="store_true", help="Include repos not tracked as submodules")
    args = parser.parse_args()

    repo_root = get_repo_root()
    submodule_map = parse_gitmodules(repo_root)

    prs = fetch_open_prs("VibeDarling")

    if args.json:
        print(json.dumps(prs, indent=2))
        return

    # Group PRs by repository name
    by_repo = {}
    for pr in prs:
        repo_name = pr["repository"]["name"]
        by_repo.setdefault(repo_name, []).append(pr)

    total_prs = 0
    matched_repos = 0

    print("=" * 80)
    print("  VibeDarling Open Pull Requests by Submodule")
    print("=" * 80)

    for repo_name in sorted(by_repo.keys()):
        repo_prs = by_repo[repo_name]
        is_submodule = repo_name.lower() in submodule_map or repo_name.lower() == "darling"

        if args.repo and args.repo.lower() not in repo_name.lower():
            continue

        if not is_submodule and not args.include_all and not args.repo:
            continue

        paths = submodule_map.get(repo_name.lower(), [])
        path_str = f" ({', '.join(paths)})" if paths else ""
        repo_header = f"📁 {repo_name}{path_str} — {len(repo_prs)} open PR(s)"
        print(f"\n{repo_header}")
        print("-" * len(repo_header))

        for pr in sorted(repo_prs, key=lambda x: x["number"]):
            total_prs += 1
            num = pr["number"]
            title = pr["title"]
            author = pr.get("author", {}).get("login", "unknown")
            branch = pr.get("headRefName", "")
            draft_str = " [DRAFT]" if pr.get("isDraft") else ""
            url = pr.get("url", "")

            print(f"  #{num:<4} {title}{draft_str}")
            print(f"         Author: @{author} | Branch: {branch}")
            print(f"         URL:    {url}")

        matched_repos += 1

    print("\n" + "=" * 80)
    print(f"Total: {total_prs} open PR(s) found across {matched_repos} repository/repositories.")
    print("=" * 80)


if __name__ == "__main__":
    main()
