#!/usr/bin/env python3
"""Lock and integrate VibeDarling default branches plus their open PR heads.

The lock is a point-in-time input list. Checkout creates an independent clone;
it never updates an existing checkout, build directory, or prefix.
"""

import argparse
import concurrent.futures
import datetime
import http.client
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


OWNER = "VibeDarling"
ROOT = "https://github.com/VibeDarling/darling.git"
SHA = re.compile(r"^[0-9a-f]{40}$")


def run(*args, cwd=None, env=None, stream=False):
    if stream:
        p = subprocess.run(args, cwd=cwd, env=env)
        if p.returncode:
            raise RuntimeError(f"{' '.join(map(str, args))}: exited {p.returncode}; see command output")
        return ""
    p = subprocess.run(args, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
    if p.returncode:
        raise RuntimeError(f"{' '.join(map(str, args))}: {p.stderr.strip()}")
    return p.stdout.strip()


def api(path):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "darling-pr-prefix"}
    if os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GITHUB_TOKEN"]
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(
                    "https://api.github.com" + path, headers=headers), timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code not in (502, 503, 504) or attempt == 2:
                raise RuntimeError(f"GitHub API {path}: HTTP {error.code}: {error.read().decode()}") from error
        except (urllib.error.URLError, http.client.RemoteDisconnected, TimeoutError) as error:
            if attempt == 2:
                raise RuntimeError(f"GitHub API {path}: connection failed after 3 attempts: {error}") from error
        time.sleep(attempt + 1)


def modules(root, allow_external=False, required_prefix="src/external/"):
    text = run("git", "show", "HEAD:.gitmodules", cwd=root)
    data = []
    section = None
    for line in text.splitlines():
        match = re.match(r'^\[submodule "([^"]+)"\]$', line)
        if match:
            if section:
                data.append(section)
            section = {"name": match.group(1)}
        elif section and "=" in line:
            key, value = line.strip().split("=", 1)
            section[key.strip()] = value.strip()
    if section:
        data.append(section)
    paths = set()
    result = []
    by_repo = {}
    for item in data:
        path, url = item.get("path"), item.get("url")
        if not path or not url or path in paths or path.startswith("/") or ".." in Path(path).parts or (required_prefix and not path.startswith(required_prefix)):
            raise RuntimeError(f"invalid .gitmodules entry: {item}")
        paths.add(path)
        if re.fullmatch(r"\.\./[A-Za-z0-9_.-]+(?:\.git)?", url):
            repo = url[3:].removesuffix(".git")
            clone_url = f"https://github.com/{OWNER}/{repo}.git"
            kind = "VibeDarling"
        elif allow_external and re.fullmatch(
                r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?", url):
            repo = url.removeprefix("https://github.com/").removesuffix(".git")
            clone_url = url
            kind = "external"
            if repo.lower().startswith(OWNER.lower() + "/"):
                raise RuntimeError(f"unexpected absolute VibeDarling URL: {url}")
        else:
            raise RuntimeError(f"unsupported submodule URL (scope must be audited): {url}")
        requested_branch = item.get("branch")
        key = (repo.lower(), requested_branch)
        if key in by_repo:
            by_repo[key]["paths"].append(path)
        else:
            entry = {"repo": repo, "paths": [path], "url": clone_url, "kind": kind}
            if requested_branch:
                entry["requested_branch"] = requested_branch
            by_repo[key] = entry
            result.append(entry)
    return result


def open_prs():
    found = []
    page = 1
    while True:
        query = urllib.parse.urlencode({"q": f"org:{OWNER} is:pr is:open",
                                        "per_page": 100, "page": page})
        response = api("/search/issues?" + query)
        if response.get("incomplete_results"):
            raise RuntimeError("GitHub search was incomplete")
        found += response["items"]
        if len(found) >= response["total_count"]:
            break
        if page == 10:
            raise RuntimeError("GitHub search exceeded its 1000-result limit")
        page += 1
    if len({(p["repository_url"], p["number"]) for p in found}) != len(found):
        raise RuntimeError("duplicate PR in GitHub search")
    return found


def remote_refs(item):
    patterns = ["HEAD", "refs/heads/main", "refs/heads/master"]
    requested = item.get("requested_branch")
    if requested:
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_./-]*", requested) or ".." in requested:
            raise RuntimeError(f"invalid declared branch for {item['repo']}: {requested}")
        patterns.append(f"refs/heads/{requested}")
    patterns += [f"refs/pull/{p['number']}/head" for p in item["prs"]]
    output = run("git", "ls-remote", "--symref", item["url"], *patterns)
    refs = {}
    default = None
    for line in output.splitlines():
        if line.startswith("ref: "):
            target, name = line[5:].split("\t", 1)
            if name == "HEAD":
                default = target
        else:
            commit, name = line.split("\t", 1)
            if not SHA.fullmatch(commit):
                raise RuntimeError(f"invalid ref SHA in {item['repo']}: {line}")
            refs[name] = commit
    if not default or not default.startswith("refs/heads/"):
        raise RuntimeError(f"{item['repo']}: cannot resolve default branch: {default}")
    if default not in refs and default not in ("refs/heads/main", "refs/heads/master"):
        refs[default] = refs.get("HEAD")
    if not refs.get(default) or refs.get(default) != refs.get("HEAD"):
        raise RuntimeError(f"{item['repo']}: missing or inconsistent default HEAD")
    selected = f"refs/heads/{requested}" if requested else default
    if selected not in refs:
        raise RuntimeError(f"{item['repo']}: declared branch {requested} is missing")
    item["branch"] = selected.removeprefix("refs/heads/")
    item["base"] = refs[selected]
    if item["branch"] not in ("main", "master"):
        item["branch_exception"] = ("declared version branch" if requested else
                                    "default branch has no main/master ref")
    for pr in item["prs"]:
        ref = f"refs/pull/{pr['number']}/head"
        if ref not in refs:
            detail = api(f"/repos/{OWNER}/{item['repo']}/pulls/{pr['number']}")
            if detail.get("state") != "open" or detail.get("merged"):
                raise RuntimeError(f"{item['repo']} PR #{pr['number']}: missing {ref}; live PR is not open/unmerged; re-resolve")
            head = detail["head"]
            url = (head.get("repo") or {}).get("clone_url", "")
            branch = head["ref"]
            if not re.fullmatch(r"https://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.git", url) or not SHA.fullmatch(head["sha"]):
                raise RuntimeError("missing PR ref has no valid declared GitHub head source")
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_./-]*", branch) or ".." in branch:
                raise RuntimeError("invalid declared PR head branch")
            head_ref = "refs/heads/" + branch
            advertised = run("git", "ls-remote", url, head_ref)
            if advertised != head["sha"] + "\t" + head_ref:
                raise RuntimeError(f"{item['repo']} PR #{pr['number']}: declared fork head differs from live API SHA")
            refs[ref] = head["sha"]
            pr["head_source"] = {"url": url, "ref": head_ref, "sha": head["sha"],
                                 "reason": f"missing {ref}; exact live PR head verified against declared fork branch"}
        pr["head"] = refs[ref]
        pr["ref"] = ref
    return item


def resolve(args):
    source = Path(args.source).resolve()
    if run("git", "remote", "get-url", "origin", cwd=source) != ROOT:
        raise RuntimeError("source origin must be the VibeDarling superproject")
    if run("git", "status", "--porcelain", cwd=source):
        raise RuntimeError("source must be clean")
    items = [{"repo": "darling", "paths": ["."], "url": ROOT}] + modules(source)
    by_repo = {}
    for item in items:
        by_repo.setdefault(item["repo"].lower(), []).append(item)
    excluded = []
    for pr in ([] if args.no_prs else open_prs()):
        repo = pr["repository_url"].rsplit("/", 1)[-1]
        key = repo.lower()
        record = {"number": pr["number"], "url": pr["html_url"],
                  "title": pr["title"]}
        if key in by_repo:
            choices = by_repo[key]
            if len(choices) > 1:
                detail = api(f"/repos/{OWNER}/{repo}/pulls/{pr['number']}")
                target = detail["base"]["ref"]
                choices = [item for item in choices if item.get("requested_branch") == target]
                if not choices:
                    raise RuntimeError(f"{repo} PR #{pr['number']} targets untracked branch {target}")
            choices[0].setdefault("prs", []).append(record)
        else:
            excluded.append({"repo": repo, **record, "reason": "not a superproject or submodule"})
    for item in items:
        item.setdefault("prs", [])
        item["prs"].sort(key=lambda p: p["number"])
    if args.repo:
        chosen = {r.lower() for r in args.repo}
        if chosen - by_repo.keys():
            raise RuntimeError(f"unknown repository: {sorted(chosen - by_repo.keys())}")
        items = [item for item in items if item["repo"].lower() in chosen]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        items = list(pool.map(remote_refs, items))
    if not args.repo and items[0]["base"] != run("git", "rev-parse", "HEAD", cwd=source):
        raise RuntimeError("source HEAD is stale; fetch and check out current VibeDarling master")
    lock = {"schema": 1, "owner": OWNER,
            "resolved_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "complete": not bool(args.repo), "no_prs": args.no_prs, "repos": items,
            "excluded_open_prs": excluded}
    out = Path(args.output).resolve()
    if out.exists():
        raise RuntimeError(f"refusing to overwrite lock: {out}")
    out.write_text(json.dumps(lock, indent=2) + "\n")
    print(f"locked {len(items)} checkout entries, "
          f"{len({i['repo'].lower() for i in items})} repositories, "
          f"and {sum(len(i['prs']) for i in items)} PRs: {out}")
    print(f"excluded {len(excluded)} open PRs outside the dependency tree")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    discover = commands.add_parser("resolve", help="lock live VibeDarling refs")
    discover.add_argument("--source", default=".")
    discover.add_argument("--output", required=True)
    discover.add_argument("--repo", action="append", help="limited diagnostic resolution only")
    discover.add_argument("--jobs", type=int, default=8)
    discover.add_argument("--no-prs", action="store_true", help="lock the default branches only and skip open pull requests")
    args = parser.parse_args()
    if getattr(args, "jobs", 1) < 1:
        parser.error("--jobs must be positive")
    try:
        {"resolve": resolve}[args.command](args)
    except (RuntimeError, OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
