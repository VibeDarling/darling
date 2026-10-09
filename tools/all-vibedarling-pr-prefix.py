#!/usr/bin/env python3
"""Lock and integrate VibeDarling default branches plus their open PR heads.

The lock is a point-in-time input list. Checkout creates an independent clone;
it never updates an existing checkout, build directory, or prefix.
"""

import argparse
import concurrent.futures
import datetime
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import shutil
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
RESOLUTIONS = []
RESUME = False


def resolve_conflict(repo, item, pr, env):
    before = run("git", "rev-parse", "HEAD^{tree}", cwd=repo)
    stages = run("git", "ls-files", "--unmerged", cwd=repo)
    matches = [r for r in RESOLUTIONS if r["repo"] == item["repo"]
               and r["pr"] == pr["number"] and r["head"] == pr["head"]
               and r["before_tree"] == before and r["stages"] == stages]
    if len(matches) != 1 or not stages:
        raise RuntimeError(f"unapproved conflict in {item['repo']} PR #{pr['number']}; "
                           f"before tree {before}; inspect git ls-files --unmerged")
    rule = matches[0]
    paths = {line.split("\t", 1)[1] for line in stages.splitlines()}
    if paths != set(rule["files"]):
        raise RuntimeError("resolution must cover exactly the conflicted paths")
    for name, content in rule["files"].items():
        path = Path(name)
        if path.is_absolute() or ".." in path.parts or ".git" in path.parts:
            raise RuntimeError("unsafe resolution path")
        target = repo / path
        if target.is_symlink() or repo.resolve() not in target.resolve().parents:
            raise RuntimeError("resolution path escapes repository")
        target.write_text(content)
        run("git", "add", "--", name, cwd=repo)
    if run("git", "ls-files", "--unmerged", cwd=repo):
        raise RuntimeError("resolution left unmerged paths")
    tree = run("git", "write-tree", cwd=repo)
    audit_path = repo / ".git/darling-pr-resolutions.json"
    audit = json.loads(audit_path.read_text()) if audit_path.exists() else []
    audit.append({**rule, "result_tree": tree, "result_blobs": {
        name: run("git", "rev-parse", f":{name}", cwd=repo) for name in paths}})
    audit_path.write_text(json.dumps(audit, indent=2) + "\n")
    run("git", "commit", "--no-edit", cwd=repo, env=env)


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


def object_at(repo, sha, fallback):
    try:
        run("git", "cat-file", "-e", sha + "^{commit}", cwd=repo)
        return
    except RuntimeError:
        pass
    try:
        run("git", "fetch", "origin", sha, cwd=repo, timeout=CLONE_TIMEOUT)
    except RuntimeError:
        run("git", "fetch", "origin", fallback, cwd=repo, retries=ATTEMPTS - 1)
    run("git", "cat-file", "-e", sha + "^{commit}", cwd=repo)


def ensure_merge_base(repo, head):
    if subprocess.run(["git", "merge-base", "HEAD", head], cwd=repo,
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        if run("git", "rev-parse", "--is-shallow-repository", cwd=repo) == "true":
            run("git", "fetch", "--unshallow", "origin", cwd=repo, retries=ATTEMPTS - 1)


def integrate(repo, item):
    object_at(repo, item["base"], f"refs/heads/{item['branch']}")
    if not RESUME:
        run("git", "checkout", "--detach", item["base"], cwd=repo)
    else:
        run("git", "merge-base", "--is-ancestor", item["base"], "HEAD", cwd=repo)
        if not (repo / ".git/MERGE_HEAD").exists():
            changed = set(run("git", "diff", "--name-only", cwd=repo).splitlines())
            changed.update(run("git", "diff", "--cached", "--name-only", cwd=repo).splitlines())
            allowed = {p for module in modules(repo, allow_external=True)
                       for p in module["paths"]} if item["repo"] == "darling" else set()
            if changed - allowed or run("git", "ls-files", "--others", "--exclude-standard", cwd=repo):
                raise RuntimeError(f"resume found unrelated source changes: {repo}")
    for pr in item["prs"]:
        if pr.get("head_source"):
            source = pr["head_source"]
            if source["sha"] != pr["head"]:
                raise RuntimeError("declared fork head does not match locked PR head")
            try:
                run("git", "cat-file", "-e", pr["head"] + "^{commit}", cwd=repo)
            except RuntimeError:
                try:
                    run("git", "fetch", source["url"], pr["head"], cwd=repo)
                except RuntimeError:
                    run("git", "fetch", source["url"], source["ref"], cwd=repo)
                run("git", "cat-file", "-e", pr["head"] + "^{commit}", cwd=repo)
        else:
            object_at(repo, pr["head"], pr["ref"])
        env = dict(os.environ, GIT_AUTHOR_NAME="Darling PR integration",
                   GIT_AUTHOR_EMAIL="integration@localhost",
                   GIT_COMMITTER_NAME="Darling PR integration",
                   GIT_COMMITTER_EMAIL="integration@localhost")
        pending = repo / ".git/MERGE_HEAD"
        if pending.exists():
            if pending.read_text().strip() != pr["head"]:
                # Earlier locked heads must already be integrated before this pending merge.
                run("git", "merge-base", "--is-ancestor", pr["head"], "HEAD", cwd=repo)
                continue
            resolve_conflict(repo, item, pr, env)
            continue
        if RESUME and not subprocess.run(["git", "merge-base", "--is-ancestor",
                                         pr["head"], "HEAD"], cwd=repo).returncode:
            continue
        ensure_merge_base(repo, pr["head"])
        try:
            run("git", "merge", "--no-ff", "--no-edit", "-m",
                f"integration: merge {item['repo']} PR #{pr['number']} ({pr['head']})",
                pr["head"], cwd=repo, env=env)
        except RuntimeError:
            if not pending.exists():
                raise
            resolve_conflict(repo, item, pr, env)
    return run("git", "rev-parse", "HEAD", cwd=repo)


def clone_shallow(url, target):
    # git checkout leaves empty directories at submodule paths; a failed attempt may
    # only clear what it created itself, never a directory that already had content.
    created = not target.exists()
    empty = target.is_dir() and not any(target.iterdir())
    for attempt in range(ATTEMPTS):
        try:
            return run("git", "clone", "--depth=1", "--no-checkout", url, str(target), timeout=CLONE_TIMEOUT)
        except RuntimeError as error:
            if target.is_dir() and (created or empty):
                for child in target.iterdir():
                    shutil.rmtree(child) if child.is_dir() and not child.is_symlink() else child.unlink()
                if created:
                    target.rmdir()
            if attempt == ATTEMPTS - 1 or PERMANENT.search(str(error)):
                raise
            time.sleep(2 ** attempt)


def clone_repository(url, target, seed=None):
    if seed and (seed / ".git").exists():
        run("git", "clone", "--no-local", "--no-checkout", str(seed), str(target))
        run("git", "remote", "set-url", "origin", url, cwd=target)
        objects = Path(run("git", "rev-parse", "--git-path", "lfs/objects", cwd=seed))
        if not objects.is_absolute():
            objects = seed / objects
        if objects.is_dir():
            shutil.copytree(objects, target / ".git/lfs/objects", dirs_exist_ok=True)
    else:
        clone_shallow(url, target)


def clone_and_integrate(source, item, seed_root):
    commits = []
    for path in item["paths"]:
        target = source / path
        if target.is_symlink() or source.resolve() not in target.resolve().parents:
            raise RuntimeError(f"checkout path escapes private source: {target}")
        if RESUME and ((target / ".git").is_file() or (target / ".git/objects/info/alternates").exists()):
            raise RuntimeError(f"resume requires independent Git storage: {target}")
        target.parent.mkdir(parents=True, exist_ok=True)
        seed = seed_root / path if seed_root else None
        if not (RESUME and (target / ".git").is_dir()):
            clone_repository(item["url"], target, seed)
            # Newly cloned seeds require checkout of the locked base even on resume.
            if RESUME:
                object_at(target, item["base"], f"refs/heads/{item['branch']}")
                run("git", "checkout", "--detach", item["base"], cwd=target)
        elif run("git", "remote", "get-url", "origin", cwd=target) != item["url"]:
            raise RuntimeError(f"resume origin mismatch: {target}")
        commits.append(integrate(target, item))
    if len(set(commits)) != 1:
        raise RuntimeError(f"repeated checkout paths diverged for {item['repo']}")
    return item, commits[0]


def checkout(args):
    global RESUME, RESOLUTIONS
    RESUME = bool(getattr(args, "resume", False))
    RESOLUTIONS = json.loads(Path(args.resolutions).read_text()) if getattr(args, "resolutions", None) else []
    lock = json.loads(Path(args.lock).read_text())
    if lock.get("schema") != 1 or lock.get("owner") != OWNER or not lock.get("complete"):
        raise RuntimeError("checkout requires a complete VibeDarling schema-1 lock")
    items = lock["repos"]
    if not items or items[0]["repo"] != "darling":
        raise RuntimeError("lock has no superproject")
    workspace = Path(args.workspace).resolve()
    if workspace.exists() and not RESUME:
        raise RuntimeError(f"refusing existing workspace: {workspace}")
    if RESUME:
        if (workspace / "refs.lock.json").read_bytes() != Path(args.lock).read_bytes():
            raise RuntimeError("resume lock differs from original input")
        if any((workspace / p).exists() for p in ("integrated.json", "build", "image", "prefix")):
            raise RuntimeError("resume requires an unfinished, unbuilt checkout")
    else:
        workspace.mkdir(parents=True)
        shutil.copy2(args.lock, workspace / "refs.lock.json")
    source = workspace / "source"
    if RESUME:
        if run("git", "remote", "get-url", "origin", cwd=source) != ROOT:
            raise RuntimeError("resume superproject origin mismatch")
    elif args.seed_superproject:
        seed = Path(args.seed_superproject).resolve()
        if run("git", "remote", "get-url", "origin", cwd=seed) != ROOT:
            raise RuntimeError("seed clone must have VibeDarling origin")
        clone_repository(ROOT, source, seed)
    else:
        clone_shallow(ROOT, source)
    integrated = {".": integrate(source, items[0])}
    expected = {(x["repo"].lower(), p, x["url"]) for x in items[1:] for p in x["paths"]}
    merged_modules = modules(source, allow_external=True)
    actual = {(x["repo"].lower(), p, x["url"]) for x in merged_modules for p in x["paths"]}
    if not expected.issubset(actual):
        raise RuntimeError("superproject PRs removed or changed locked .gitmodules entries")
    additions = [x for x in merged_modules if x["kind"] == "external"]
    if actual - expected != {(x["repo"].lower(), p, x["url"])
                            for x in additions for p in x["paths"]}:
        raise RuntimeError("superproject PRs added a VibeDarling submodule absent from the lock")
    seed_root = Path(args.seed_submodules_root).resolve() if args.seed_submodules_root else None
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for start in range(1, len(items), args.jobs):
            batch = items[start:start + args.jobs]
            futures = {pool.submit(clone_and_integrate, source, item, seed_root): item
                       for item in batch}
            for future in concurrent.futures.as_completed(futures):
                try:
                    item, sha = future.result()
                except RuntimeError as error:
                    raise RuntimeError(f"{futures[future]['repo']}: {error}") from error
                for path in item["paths"]:
                    integrated[path] = sha
                for path in item["paths"]:
                    run("git", "add", "--", path, cwd=source)
                print(f"integrated {item['repo']}: {sha}", flush=True)
    external = []
    for item in additions:
        for path in item["paths"]:
            line = run("git", "ls-tree", "HEAD", "--", path, cwd=source)
            match = re.fullmatch(r"160000 commit ([0-9a-f]{40})\t(.+)", line)
            if not match or match.group(2) != path:
                raise RuntimeError(f"PR-added submodule has no gitlink commit: {path}")
            sha = match.group(1)
            target = source / path
            target.parent.mkdir(parents=True, exist_ok=True)
            clone_repository(item["url"], target, seed_root / path if seed_root else None)
            object_at(target, sha, "HEAD")
            run("git", "checkout", "--detach", sha, cwd=target)
            external.append({"path": path, "url": item["url"], "gitlink": sha})
    env = dict(os.environ, GIT_AUTHOR_NAME="Darling PR integration",
               GIT_AUTHOR_EMAIL="integration@localhost",
               GIT_COMMITTER_NAME="Darling PR integration",
               GIT_COMMITTER_EMAIL="integration@localhost")
    if run("git", "diff", "--cached", "--name-only", cwd=source):
        run("git", "commit", "-m", "integration: pin VibeDarling default branches and open PRs",
            cwd=source, env=env)
    audits = {}
    for path in integrated:
        audit = source / path / ".git/darling-pr-resolutions.json"
        if audit.exists():
            audits[path] = json.loads(audit.read_text())
    (workspace / "integrated.json").write_text(json.dumps(
        {"repositories": integrated, "pr_added_external_submodules": external,
         "merge_resolutions": audits}, indent=2) + "\n")
    print(f"integrated source: {source}")
    print(f"superproject commit: {run('git', 'rev-parse', 'HEAD', cwd=source)}")


def nested_modules(workspace):
    source = workspace / "source"
    top = json.loads((workspace / "refs.lock.json").read_text())
    found = []
    for item in top["repos"][1:]:
        for parent_path in item["paths"]:
            parent = source / parent_path
            if (parent / ".gitmodules").is_file():
                for module in modules(parent, allow_external=True, required_prefix=None):
                    for subpath in module["paths"]:
                        line = run("git", "ls-tree", "HEAD", "--", subpath, cwd=parent)
                        match = re.fullmatch(r"160000 commit ([0-9a-f]{40})\t(.+)", line)
                        if not match or match.group(2) != subpath:
                            raise RuntimeError(f"nested module has no gitlink: {parent_path}/{subpath}")
                        found.append({"parent": parent_path, "path": subpath,
                                      "repo": module["repo"], "url": module["url"],
                                      "kind": module["kind"], "pin": match.group(1)})
    return found


def resolve_nested(args):
    workspace = Path(args.workspace).resolve()
    if not (workspace / "integrated.json").is_file():
        raise RuntimeError("complete top-level checkout first")
    occurrences = nested_modules(workspace)
    by_repo = {}
    external = []
    for occurrence in occurrences:
        if occurrence["kind"] == "external":
            external.append(occurrence)
        else:
            key = occurrence["repo"].lower()
            if key not in by_repo:
                by_repo[key] = {"repo": occurrence["repo"], "url": occurrence["url"],
                                "occurrences": [], "prs": []}
            by_repo[key]["occurrences"].append(occurrence)
    top = json.loads((workspace / "refs.lock.json").read_text())
    top_repos = {item["repo"].lower() for item in top["repos"]}
    if args.no_prs and not top.get("no_prs"):
        raise RuntimeError("--no-prs conflicts with the top-level lock, which includes open PRs")
    no_prs = bool(top.get("no_prs"))
    prs = [] if no_prs else open_prs()
    for pr in prs:
        repo = pr["repository_url"].rsplit("/", 1)[-1].lower()
        if repo in by_repo:
            by_repo[repo]["prs"].append(pr_record(pr))
        elif repo not in top_repos and not any(
                p["repo"].lower() == repo for p in top["excluded_open_prs"]):
            raise RuntimeError(f"PR set changed since top-level lock: {pr['html_url']}")
    items = list(by_repo.values())
    for item in items:
        item["prs"].sort(key=lambda p: p["number"])
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        items = list(pool.map(remote_refs, items))
    lock = {"schema": 1, "owner": OWNER, "no_prs": no_prs,
            "excluded_open_prs": off_branch_exclusions(items),
            "resolved_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "top_lock_sha256": hashlib.sha256((workspace / "refs.lock.json").read_bytes()).hexdigest(),
            "vibedarling": items, "external_pinned": external}
    output = Path(args.output).resolve()
    if output.exists():
        raise RuntimeError(f"refusing to overwrite nested lock: {output}")
    output.write_text(json.dumps(lock, indent=2) + "\n")
    print(f"locked {len(items)} nested VibeDarling repos and {len(external)} external pins: {output}")


def checkout_nested(args):
    global RESUME, RESOLUTIONS
    RESUME = bool(getattr(args, "resume", False))
    RESOLUTIONS = json.loads(Path(args.resolutions).read_text()) if getattr(args, "resolutions", None) else []
    workspace = Path(args.workspace).resolve()
    source = workspace / "source"
    lock = json.loads(Path(args.lock).read_text())
    if lock.get("schema") != 1 or lock.get("owner") != OWNER:
        raise RuntimeError("invalid nested lock")
    digest = hashlib.sha256((workspace / "refs.lock.json").read_bytes()).hexdigest()
    if digest != lock.get("top_lock_sha256"):
        raise RuntimeError("nested lock belongs to a different top-level lock")
    if (workspace / "nested.integrated.json").exists():
        raise RuntimeError("nested integration already completed")
    if any((workspace / p).exists() for p in ("build", "image", "prefix")):
        raise RuntimeError("nested integration requires an unbuilt workspace")
    retained_lock = workspace / "nested.refs.lock.json"
    if retained_lock.exists() and retained_lock.read_bytes() != Path(args.lock).read_bytes():
        raise RuntimeError("nested resume lock differs from original input")
    current = nested_modules(workspace)
    expected = [o for item in lock["vibedarling"] for o in item["occurrences"]]
    expected += lock["external_pinned"]
    if sorted(current, key=lambda x: (x["parent"], x["path"])) != sorted(
            expected, key=lambda x: (x["parent"], x["path"])):
        raise RuntimeError("nested submodule map changed since nested lock")
    if not retained_lock.exists():
        shutil.copy2(args.lock, retained_lock)
    changed_parents = set()
    realized = []
    seed_root = Path(args.seed_submodules_root).resolve() if args.seed_submodules_root else None
    for item in lock["vibedarling"]:
        for o in item["occurrences"]:
            parent = source / o["parent"]
            target = parent / o["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            seed = seed_root / o["parent"] / o["path"] if seed_root else None
            if RESUME and (target / ".git").is_dir():
                if target.is_symlink() or (target / ".git/objects/info/alternates").exists():
                    raise RuntimeError("nested resume requires independent Git storage")
                if run("git", "remote", "get-url", "origin", cwd=target) != item["url"]:
                    raise RuntimeError("nested resume origin mismatch")
            else:
                clone_repository(item["url"], target, seed)
                if RESUME:
                    object_at(target, item["base"], f"refs/heads/{item['branch']}")
                    run("git", "checkout", "--detach", item["base"], cwd=target)
            sha = integrate(target, item)
            if (target / ".gitmodules").is_file():
                raise RuntimeError(f"deeper nested modules need a new integration step: {target}")
            run("git", "add", "--", o["path"], cwd=parent)
            changed_parents.add(o["parent"])
            record = {"path": str(Path(o["parent"]) / o["path"]),
                      "repo": item["repo"], "commit": sha}
            audit = target / ".git/darling-pr-resolutions.json"
            if audit.exists():
                record["merge_resolutions"] = json.loads(audit.read_text())
            realized.append(record)
    for o in lock["external_pinned"]:
        parent = source / o["parent"]
        target = parent / o["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        seed = seed_root / o["parent"] / o["path"] if seed_root else None
        if RESUME and (target / ".git").is_dir():
            if target.is_symlink() or (target / ".git/objects/info/alternates").exists():
                raise RuntimeError("external resume requires independent Git storage")
            if run("git", "remote", "get-url", "origin", cwd=target) != o["url"] or run("git", "status", "--porcelain", cwd=target):
                raise RuntimeError("external resume origin/source mismatch")
        else:
            clone_repository(o["url"], target, seed)
        object_at(target, o["pin"], "HEAD")
        run("git", "checkout", "--detach", o["pin"], cwd=target)
        if (target / ".gitmodules").is_file():
            raise RuntimeError(f"deeper nested modules need a new integration step: {target}")
        realized.append({"path": str(Path(o["parent"]) / o["path"]),
                         "repo": o["repo"], "commit": o["pin"]})
    env = dict(os.environ, GIT_AUTHOR_NAME="Darling PR integration",
               GIT_AUTHOR_EMAIL="integration@localhost",
               GIT_COMMITTER_NAME="Darling PR integration",
               GIT_COMMITTER_EMAIL="integration@localhost")
    for parent_path in changed_parents:
        parent = source / parent_path
        if run("git", "diff", "--cached", "--name-only", cwd=parent):
            run("git", "commit", "-m", "integration: pin nested VibeDarling repositories",
                cwd=parent, env=env)
            run("git", "add", "--", parent_path, cwd=source)
    if run("git", "diff", "--cached", "--name-only", cwd=source):
        run("git", "commit", "-m", "integration: pin nested VibeDarling repositories",
            cwd=source, env=env)
    (workspace / "nested.integrated.json").write_text(json.dumps(realized, indent=2) + "\n")
    print(f"integrated {len(realized)} nested paths; superproject {run('git', 'rev-parse', 'HEAD', cwd=source)}")


def supplement(args):
    workspace = Path(args.workspace).resolve()
    source = workspace / "source"
    if not (workspace / "integrated.json").is_file():
        raise RuntimeError("workspace has not completed checkout")
    if any((workspace / name).exists() for name in ("build", "image", "prefix")):
        raise RuntimeError("supplements require an unconfigured workspace")
    if nested_modules(workspace) and not (workspace / "nested.integrated.json").is_file():
        raise RuntimeError("complete nested integration before adding supplements")
    if run("git", "status", "--porcelain", cwd=source):
        raise RuntimeError("integrated source is dirty")
    if not SHA.fullmatch(args.commit):
        raise RuntimeError("supplement requires a full 40-character commit SHA")
    entries = [item for item in modules(source, allow_external=True)
               if args.path in item["paths"] and item["kind"] == "VibeDarling"]
    if len(entries) != 1:
        raise RuntimeError("supplement path must name a top-level VibeDarling submodule")
    target = source / args.path
    donor = Path(args.from_repo).resolve()
    if not (target / ".git").is_dir() or not (donor / ".git").is_dir() or target.resolve() == donor:
        raise RuntimeError("target and donor must be distinct independent Git clones")
    if run("git", "remote", "get-url", "origin", cwd=donor) != entries[0]["url"]:
        raise RuntimeError("donor origin does not match the locked VibeDarling repository")
    run("git", "cat-file", "-e", args.commit + "^{commit}", cwd=donor)
    if run("git", "rev-parse", args.commit + "^{commit}", cwd=donor) != args.commit:
        raise RuntimeError("supplement SHA must identify a commit, not a tag")
    manifest_path = workspace / "supplements.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        "schema": 1, "inputs": []}
    if any(item["status"] != "complete" for item in manifest["inputs"]):
        raise RuntimeError("an earlier supplement failed; inspect its workspace")
    if manifest["inputs"] and manifest["inputs"][-1]["superproject_result"] != run(
            "git", "rev-parse", "HEAD", cwd=source):
        raise RuntimeError("source no longer matches its recorded supplements")
    run("git", "fetch", "--no-tags", "--no-write-fetch-head", str(donor), args.commit, cwd=target)
    before = run("git", "rev-parse", "HEAD", cwd=target)
    if run("git", "diff", before, args.commit, "--", ".gitmodules", cwd=target):
        raise RuntimeError("supplement changes submodule metadata; resolve a new dependency lock")
    changes = run("git", "diff", "--raw", before, args.commit, cwd=target)
    if any("160000" in [mode.lstrip(":") for mode in line.split()[:2]]
           for line in changes.splitlines()):
        raise RuntimeError("supplement changes nested gitlinks; resolve a new dependency lock")
    record = {"path": args.path, "repo": entries[0]["repo"], "source_repo": str(donor),
              "commit": args.commit, "reason": args.reason, "before": before,
              "superproject_before": run("git", "rev-parse", "HEAD", cwd=source),
              "status": "applying"}
    manifest["inputs"].append(record)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    env = dict(os.environ, GIT_AUTHOR_NAME="Darling PR integration",
               GIT_AUTHOR_EMAIL="integration@localhost",
               GIT_COMMITTER_NAME="Darling PR integration",
               GIT_COMMITTER_EMAIL="integration@localhost")
    try:
        run("git", "merge", "--no-ff", "--no-edit", "-m",
            f"integration: merge {record['repo']} supplement ({args.commit})",
            args.commit, cwd=target, env=env)
        run("git", "add", "--", args.path, cwd=source)
        if run("git", "diff", "--cached", "--name-only", cwd=source):
            run("git", "commit", "-m", f"integration: pin {record['repo']} supplement",
                cwd=source, env=env)
        record.update(status="complete", result=run("git", "rev-parse", "HEAD", cwd=target),
                      superproject_result=run("git", "rev-parse", "HEAD", cwd=source))
    except (RuntimeError, OSError) as error:
        record.update(status="failed", error=str(error), conflicts=run(
            "git", "diff", "--name-only", "--diff-filter=U", cwd=target).splitlines())
        raise RuntimeError(f"supplement failed; inspect {manifest_path} and {target}: {error}") from error
    finally:
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"supplemented source: {record['superproject_result']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    discover = commands.add_parser("resolve", help="lock live VibeDarling refs")
    discover.add_argument("--source", default=".")
    discover.add_argument("--output", required=True)
    discover.add_argument("--repo", action="append", help="limited diagnostic resolution only")
    discover.add_argument("--jobs", type=int, default=8)
    discover.add_argument("--no-prs", action="store_true", help="lock the default branches only and skip open pull requests")
    materialize = commands.add_parser("checkout", help="clone and integrate locked refs")
    materialize.add_argument("--lock", required=True)
    materialize.add_argument("--workspace", required=True)
    materialize.add_argument("--jobs", type=int, default=6)
    materialize.add_argument("--seed-superproject", help="existing independent clone to copy locally")
    materialize.add_argument("--seed-submodules-root", help="read-only populated tree to copy with --no-local")
    materialize.add_argument("--resume", action="store_true", help="continue only an unfinished checkout with identical lock")
    materialize.add_argument("--resolutions", help="reviewed exact conflict-stage/source-tree resolution JSON")
    nested_discover = commands.add_parser("resolve-nested", help="lock nested submodule refs")
    nested_discover.add_argument("--workspace", required=True)
    nested_discover.add_argument("--output", required=True)
    nested_discover.add_argument("--jobs", type=int, default=8)
    nested_discover.add_argument("--no-prs", action="store_true", help="lock the default branches only and skip open pull requests")
    nested_materialize = commands.add_parser("checkout-nested", help="integrate locked nested refs")
    nested_materialize.add_argument("--workspace", required=True)
    nested_materialize.add_argument("--lock", required=True)
    nested_materialize.add_argument("--seed-submodules-root", help="read-only populated tree to copy nested dependencies and LFS objects")
    nested_materialize.add_argument("--resume", action="store_true", help="continue unfinished nested checkout with identical lock")
    nested_materialize.add_argument("--resolutions", help="reviewed exact conflict-stage/source-tree resolution JSON")
    additional = commands.add_parser("supplement", help="merge an exact private submodule fix")
    additional.add_argument("--workspace", required=True)
    additional.add_argument("--path", required=True, help="top-level submodule path")
    additional.add_argument("--from-repo", required=True, help="read-only independent donor clone")
    additional.add_argument("--commit", required=True, help="exact committed supplement SHA")
    additional.add_argument("--reason", required=True, help="purpose and verification provenance")
    args = parser.parse_args()
    if getattr(args, "jobs", 1) < 1:
        parser.error("--jobs must be positive")
    try:
        {"resolve": resolve, "checkout": checkout,
         "resolve-nested": resolve_nested, "checkout-nested": checkout_nested,
         "supplement": supplement}[args.command](args)
    except (RuntimeError, OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
