# Issue collaboration protocol

Use this protocol when a person or agent picks up an issue in any VibeDarling repository. The GitHub issue comments are the shared coordination record. A claim covers one issue, not a repository or every task mentioned in that issue.

The long-term goal is to make Darling able, ideally, to launch every macOS application available through Homebrew casks and exercise its core workflows. Distribute the app testing space across a fleet of agents so each app gets reproducible coverage and shared library fixes help many apps. A successful install or symbol scan alone is not a working app.

## Claim an issue

1. Read the issue, recent comments, linked PRs, and the current code. Notes and older comments may be stale.
2. Challenge the issue's premise before starting implementation: reproduce the failure, check whether the proposed cause and fix fit the evidence, look for an existing implementation or newer fix, and identify missing requirements or unintended effects. Comment with evidence and ask for clarification when the scope or expected behavior is unclear. Correct or close an outdated issue rather than implementing its stale plan.
3. Check the issue's claim comments before editing code. If another contributor has a live claim, choose a different issue or ask the owner for a handoff. Takeover still waits until the claim expires. You may do read-only research and share findings without claiming.
4. If the issue is free, post a new comment with the template below. Use the account that will do the work. The comment author is the owner; GitHub's comment creation time is the authoritative start time.
5. Re-read the comments after posting. If claims raced, the earliest valid claim by GitHub creation time wins. A later claimant must stop dependent work and pick another issue.

```text
<!-- vibedarling-issue-claim:v1 -->
Status: in progress
Owner: @YOUR_GITHUB_HANDLE
TTL: 24 hours from this comment's GitHub creation time
Expires at: YYYY-MM-DD HH:MM UTC
Plan: one or two sentences describing the intended fix and repository
Work branch or PR: link when available
```

The displayed expiry is for readers; calculate it as the GitHub comment's `createdAt` plus exactly 24 hours. If it disagrees with that calculation, `createdAt` wins. Use UTC. Do not edit a claim to extend it.

## Renew, hand off, or take over

- The current owner may renew **before** expiry by posting a new claim comment with a new 24-hour TTL, current progress, and links to any branch or PR. Each valid renewal starts a fresh 24 hours at its own GitHub creation time.
- If the owner stops early, they may post `<!-- vibedarling-issue-handoff:v1 -->`, `Status: paused`, and a short handoff with what was tried and where any work lives. This **does not** shorten the claim's TTL. Another contributor may take over only after the current 24-hour claim expires.
- If a claim expires without a valid renewal, anyone may take over by posting a new claim. State that the previous claim expired, link the prior work or PR, and say what you will do next. There is no need to wait for the prior owner to respond after expiry.
- A claim or renewal from someone other than the current owner **before** expiry has no effect. A handoff does not grant early ownership. When comments race, use GitHub creation time to decide which valid claim came first; never rely on comment ordering in a local cache.
- A PR alone does not renew a claim. If work continues beyond the TTL, post a renewal. When the issue is resolved, close it through the normal PR/issue workflow; if work stops before resolution, post a handoff and let the TTL expire.

## Work without collisions

- Keep each fix in its own branch and worktree or independent clone. Check the current issue and branch ownership before changing shared files, submodule pins, or the integration environment.
- Link the issue in the PR and comment on the issue with the PR URL and current status. Explain the exact failing app or command, the root cause, the test you ran, and remaining gaps so another contributor can continue.
- Split independent blockers into separate issues so different contributors can claim them in parallel. Keep a parent issue updated with links to those blockers and their PRs.
- File additional, distinct problems discovered during implementation or review as new issues, even when they are outside the claimed scope. Include a reproducible symptom, current evidence, expected behavior, likely code or dependency area, and a concrete starting point for a person or AI agent to investigate. Link each new issue from the original issue or PR; do not silently expand the original claim to cover it.
- Never overwrite another contributor's branch or uncommitted work. For a takeover, start from a new branch and reuse prior changes through reviewable commits or a PR.

## Divide app testing across agents

Keep an open app-testing coordination issue with a current list of casks and applications, test status, and links to per-app issues. Assign bounded, nonoverlapping app batches to agents through 24-hour claim comments that list exact cask names and app versions; use the same ownership, renewal, and race rules as issue claims. Prioritize apps likely to run soon and shared dependencies that unblock several apps, while continuing AppZapper and SwiftUI work. Revisit assignments as installs and runtime evidence change.

For each assigned app, record its cask/version and architecture, install and launch commands, integration prefix or environment revision, direct and indirect missing libraries or symbols, observed launch and core-workflow behavior, and logs or reproduction steps. Distinguish installation, load, launch, and usable-workflow milestones. File separate actionable issues for newly found shared gaps and link them to every affected app issue; update the coordination issue so another agent can take over an expired batch without repeating the investigation.

## Account for merged work

Every merged PR and commit must be traceable to an issue. For new work, link the issue in the PR before merge; commits in that PR are covered by that issue. A direct commit without a PR needs its own linked issue. Keep the issue and PR linked in both directions.

Agents auditing existing history should coordinate through an open audit issue for each repository. Before starting a batch, check the audit issue's comments and completed ranges, then claim a **bounded, nonoverlapping** PR list or commit range in a comment with the 24-hour TTL, owner, and creation-time/race rules above. Include the exact PR numbers or commit endpoints in the claim. Renew or hand off using the same rules, and update the audit issue with the range covered and issue links when done. Do not claim an entire repository's history as one batch.

For each merged PR without a linked issue, inspect its diff, commits, discussion, and current code; create a retrospective issue in the relevant repository that links the PR and records what changed, why it appears to have been done, and what the available tests or runtime evidence actually establish. Comment on the merged PR with the issue link, then close the retrospective issue as completed. For a merged commit without a PR or issue, do the same and include its full commit URL and SHA in the issue; group commits only when they are demonstrably one logical change. A PR's commits and merge commit may all point to its one issue. Check for existing issues, backports, cherry-picks, and duplicate PRs first so one change is not documented repeatedly. Do not invent missing rationale or claim unverified behavior worked.

If the audit reveals a bug, missing test, incomplete behavior, or other gap, file a **separate open follow-up issue** with reproduction or evidence and a concrete contribution path. Link it from the retrospective issue and the original PR or commit where possible. Record any history that cannot yet be mapped to an issue in the audit issue for another agent to investigate; do not mark that batch complete until every merged item in it has an issue link.

## Audit existing code

Audit committed code even when it already has an issue or passed PR review. Use an open audit issue in the relevant repository to divide work into bounded code areas. Before starting, check other audit claims and post a 24-hour claim naming the paths or subsystem and the commit being inspected; use the same ownership, renewal, and race rules as above. Avoid overlapping another live claim.

Read the implementation, its callers and dependencies, relevant tests, and the behavior it promises. Challenge assumptions about correctness, simplicity, security, failure handling, resource ownership, and concurrency. Run focused builds, tests, or guest app workflows where practical; distinguish observed results from source-only inferences. Check whether a suspected gap is already fixed on the current branch or tracked in an existing issue.

Report the audited revision and paths, checks run, evidence found, and areas not yet inspected in the audit issue. For each distinct gap, create or update an **open, actionable issue** with the affected code and commit/PR links, expected and actual behavior, reproduction or source evidence, impact, a plausible fix path, and a way to verify a fix. Link these issues from the audit record and the original PR when applicable. Do not call an area complete because no test failed; mark it audited only after recording both the checks performed and their limits.

## Independent PR reviews

Before merging any VibeDarling PR, get **at least five approvals from five different people** on the current PR head commit. Each reviewer may use their own agent to inspect the contribution, but the review must be posted from that person's own GitHub account. Several agents or accounts operated by one person count as one reviewer; the PR author and anyone who contributed commits do not count. Reviewers should make their own assessment rather than repeat another review or share one agent's conclusion.

Ask reviewers to examine the complete diff and relevant surrounding code, run or inspect appropriate tests, and submit a GitHub PR review that addresses all three areas:

- **Correctness:** Does the change solve the stated problem without breaking related behavior? Include the test result or other evidence checked.
- **Simplicity:** Is the implementation understandable and no more complex than needed? Point out unnecessary code or a simpler approach when applicable.
- **Security:** Check trust boundaries, input handling, permissions, secrets, and dependency changes where relevant. State what was checked even when no issue was found.

Reviewers should leave inline comments for specific problems and use GitHub's **Request changes** review state for blocking concerns. An approval must include a short, substantive explanation of the three checks; an unqualified “LGTM,” a plain PR comment, or an agent message outside GitHub does not count. The person posting the review is accountable for its conclusion.

After any PR head change, reviewers must inspect the new head and submit fresh approvals. Before merging, the maintainer must verify that five eligible, distinct people have approved the **current head commit**, that no blocking review or unresolved blocking conversation remains, and that required checks pass. If any condition is unmet, leave the PR open. This protocol applies to the PR introducing it as well.
