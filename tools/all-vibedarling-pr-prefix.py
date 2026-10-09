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
ATTEMPTS = 4
MAX_RETRY_WAIT = 60
SECONDARY_WAIT = 30
NETWORK_TIMEOUT = 120
CLONE_TIMEOUT = 1800
PERMANENT = re.compile(r"not found|could not resolve host|authentication failed|"
                       r"terminal prompts disabled|returned error: 40[134]", re.I)


def run(*args, cwd=None, env=None, stream=False, retries=0, timeout=None):
    if retries and timeout is None:
        timeout = CLONE_TIMEOUT
    for attempt in range(retries):
        try:
            return run(*args, cwd=cwd, env=env, stream=stream, timeout=timeout)
        except RuntimeError as error:
            if PERMANENT.search(str(error)):
                raise
            time.sleep(2 ** attempt)
    if stream:
        p = subprocess.run(args, cwd=cwd, env=env)
        if p.returncode:
            raise RuntimeError(f"{' '.join(map(str, args))}: exited {p.returncode}; see command output")
        return ""
    try:
        p = subprocess.run(args, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(f"{' '.join(map(str, args))}: timed out after {timeout}s") from error
    if p.returncode:
        raise RuntimeError(f"{' '.join(map(str, args))}: {p.stderr.strip()}")
    return p.stdout.strip()


def rate_limit_error(path, why):
    return RuntimeError(f"GitHub API {path}: rate limited ({why}); set GITHUB_TOKEN or run gh auth login")


def api(path):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "darling-pr-prefix"}
    if os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GITHUB_TOKEN"]
    secondary_retried = False
    for attempt in range(ATTEMPTS):
        delay = 2 ** attempt
        try:
            with urllib.request.urlopen(urllib.request.Request(
                    "https://api.github.com" + path, headers=headers), timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            body = error.read().decode()
            failure = RuntimeError(f"GitHub API {path}: HTTP {error.code}: {body}")
            retry_after = error.headers.get("Retry-After", "")
            if error.code in (403, 429, 502, 503, 504) and retry_after.isdecimal():
                if int(retry_after) > MAX_RETRY_WAIT:
                    raise rate_limit_error(path, f"Retry-After {retry_after}s exceeds the {MAX_RETRY_WAIT}s budget") from error
                delay = int(retry_after)
            elif error.code == 403 and error.headers.get("X-RateLimit-Remaining") == "0":
                reset = int(error.headers.get("X-RateLimit-Reset", "0"))
                if reset - time.time() > MAX_RETRY_WAIT:
                    when = datetime.datetime.fromtimestamp(reset, datetime.timezone.utc).isoformat()
                    raise rate_limit_error(path, f"limit resets at {when}") from error
                delay = max(reset - int(time.time()), 1)
            elif error.code == 403 and "secondary rate limit" in body.lower():
                if secondary_retried:
                    raise rate_limit_error(path, "secondary limit persists") from error
                secondary_retried, delay = True, SECONDARY_WAIT
            elif error.code not in (429, 502, 503, 504):
                raise failure from error
            if attempt == ATTEMPTS - 1:
                raise (rate_limit_error(path, f"HTTP {error.code} after {ATTEMPTS} attempts")
                       if error.code in (403, 429) else failure) from error
        except (urllib.error.URLError, http.client.HTTPException, ConnectionError, TimeoutError) as error:
            if attempt == ATTEMPTS - 1:
                raise RuntimeError(f"GitHub API {path}: connection failed after {ATTEMPTS} attempts: {error}") from error
        time.sleep(delay)


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
    try:
        output = run("git", "ls-remote", "--symref", item["url"], *patterns, retries=ATTEMPTS - 1,
                     timeout=NETWORK_TIMEOUT)
    except RuntimeError as error:
        raise RuntimeError(f"{item['repo']}: {error}") from error
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
    item["off_branch_prs"] = [pr for pr in item["prs"] if pr["base"] != item["branch"]]
    item["prs"] = [pr for pr in item["prs"] if pr["base"] == item["branch"]]
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


def pr_record(pr):
    repo = pr["repository_url"].rsplit("/", 1)[-1]
    base = api(f"/repos/{OWNER}/{repo}/pulls/{pr['number']}")["base"]["ref"]
    return {"number": pr["number"], "url": pr["html_url"], "title": pr["title"], "base": base}


def off_branch_exclusions(items):
    return [{"repo": item["repo"], "number": pr["number"], "url": pr["url"], "title": pr["title"],
             "reason": f"targets {pr['base']}, not the locked branch {item['branch']}"}
            for item in items for pr in item.pop("off_branch_prs")]


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
    chosen = {r.lower() for r in args.repo or []}
    if chosen - by_repo.keys():
        raise RuntimeError(f"unknown repository: {sorted(chosen - by_repo.keys())}")
    for pr in ([] if args.no_prs else open_prs()):
        repo = pr["repository_url"].rsplit("/", 1)[-1]
        key = repo.lower()
        if key not in by_repo:
            excluded.append({"repo": repo, "number": pr["number"], "url": pr["html_url"],
                             "title": pr["title"], "reason": "not a superproject or submodule"})
            continue
        if chosen and key not in chosen:
            continue
        record = pr_record(pr)
        choices = by_repo[key]
        if len(choices) > 1:
            choices = [item for item in choices if item.get("requested_branch") == record["base"]]
            if not choices:
                excluded.append({"repo": repo, **{k: record[k] for k in ("number", "url", "title")},
                                 "reason": f"targets untracked branch {record['base']}"})
                continue
        choices[0].setdefault("prs", []).append(record)
    for item in items:
        item.setdefault("prs", [])
        item["prs"].sort(key=lambda p: p["number"])
    if chosen:
        items = [item for item in items if item["repo"].lower() in chosen]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        items = list(pool.map(remote_refs, items))
    excluded += off_branch_exclusions(items)
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
