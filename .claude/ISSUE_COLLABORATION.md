# Issue collaboration protocol

Use this protocol when a person or agent picks up an issue in any VibeDarling repository. The GitHub issue comments are the shared coordination record. A claim covers one issue, not a repository or every task mentioned in that issue.

## Claim an issue

1. Read the issue, recent comments, linked PRs, and the current code. Notes and older comments may be stale.
2. Check the issue's claim comments before editing code. If another contributor has a live claim, choose a different issue or ask the owner for a handoff. Takeover still waits until the claim expires. You may do read-only research and share findings without claiming.
3. If the issue is free, post a new comment with the template below. Use the account that will do the work. The comment author is the owner; GitHub's comment creation time is the authoritative start time.
4. Re-read the comments after posting. If claims raced, the earliest valid claim by GitHub creation time wins. A later claimant must stop dependent work and pick another issue.

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
- Never overwrite another contributor's branch or uncommitted work. For a takeover, start from a new branch and reuse prior changes through reviewable commits or a PR.
