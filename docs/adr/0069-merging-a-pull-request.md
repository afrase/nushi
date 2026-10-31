# 0069. Merging a pull request: the user's confirmation, at the head they saw, never past a rule of its base's

Status: accepted, 2026-10-31. Amends [0045](0045-github-through-our-own-client-gh-login-first.md) ("Merge isn't offered").

## Context
A chat's work ends in a merge, which was a trip to the browser. A merge can't be taken back and goes out in the user's name, a push can land between looking and pressing, and an admin's token is dangerous here: GitHub's `mergePullRequest` has no "as admin" flag, so what the web page asks for with a tick is what any plain call by that token does, seen merging past a required review (`docs/facts/github.md`). Whatever Nushi sends, it has to send only what the user saw.

## Decision
- **Only from the user's confirmation.** The Merge control, in the Pull request tab and the PR widget, always goes through one dialog: the method, the base, the head's commit, and for a merge or a squash the commit's title and message, editable, GitHub's own text first (`viewerMergeHeadlineText`, `viewerMergeBodyText`, asked when the dialog opens: a squash's body can be every commit's message, not worth a poll's bytes). Nushi takes no merge action by itself. Removing auto-merge or leaving the queue is a plain button: nothing is lost.
- **At the head shown.** `expectedHeadOid` is always the head the view showed, on merge, auto-merge and enqueue. The daemon compares first, GitHub again; either refusal is the reason `head_moved` (Aborted), and the app says so and reads the pull request again.
- **Never past a rule.** No control for admin bypass, and the daemon refuses a merge on its own read just before sending, whatever the app asked: only in a state GitHub says anyone may merge (`clean`, `has_hooks`, `unstable`, and `mergeable`), not a draft (GitHub says `unstable` of one), with no required check failing or running and no required review missing. Someone who could bypass (`viewerCanMergeAsAdmin`) doesn't get "changes requested" treated as advisory, as a clean state otherwise allows. `MergeBlocks` in `features/github` is the one list: the guard's and, sent as words like `checks_failing`, the app's.
- **What's offered** follows GitHub's fields: the repository's methods without what `requiresLinearHistory` forbids; write access or better (`viewerPermission`; `viewerCanUpdate` says they may update the pull request, not merge it); `viewerCanEnableAutoMerge` and `viewerCanDisableAutoMerge`. The start method is the one last picked here for the repository while it's allowed, else `viewerDefaultMergeMethod`, else the first; the pick is the app's, in `app.json`.
- **Auto-merge** (not on a queue) is offered only while it can't merge yet, as GitHub does; a clean pull request has the direct merge.
- **A merge queue** replaces the direct merge: ready, Add to queue (`enqueuePullRequest`, with the head, never `jump`); not ready, Merge when ready (`enablePullRequestAutoMerge`, which GitHub's schema says the queue takes over); in it, its position and state, and Remove from queue. The queue's own method and commit text stand: the dialog says so, and none is sent.
- **After** it reads the pull request again. Nothing is deleted: Clean up… stays the way (0063), and the dialog says when the repository deletes the branch itself (`deleteBranchOnMerge`).
- **The phone may merge, the same rule as a review** ([0034](0034-noise-between-phone-and-daemon.md): a paired device is a full client). `SubmitGitHubReview` isn't in `macOnly`, so the merge calls aren't either, and `TestPhoneMergesAsItReviews` ties them together. A paired phone can already run `gh pr merge` in a terminal, so keeping them from it would protect nothing. Today's phone app has no pull request view and posts no review, so it shows no control: when it gets one, it uses the same confirmation.
- **No agent merges through Nushi.** No MCP tool reaches a merge, and `TestAgentsGetNoGitHubTools` fails if a tool set is added. The limit of this: an agent runs as the user, so it can run `gh pr merge` or read the client token (ADR 0024) and call the API. Nushi offers it no way; the harness's permissions are what stop those.

## Consequences
- The query spends no more points: the new fields are scalars and single objects.
- Each write reads the pull request whole first: about 2 points, for something a person does by hand.
- A rule GitHub doesn't name in its fields ("rules") shows as "A rule of main's isn't met". Rulesets aren't read; `refUpdateRule` covers branch protection only.
- GitHub's words for a refused head are matched as text, in two wordings. If they change, the refusal shows as GitHub's message with no re-read until the next poll; nothing merges either way.
- An old Enterprise server without these fields fails the whole pull request query, not only the control.
- The merge queue was never run live: it needs an organization's plan. Its code follows GitHub's published schema.

## Alternatives considered
- Mergeability read from `mergeStateStatus` alone: a draft reads `unstable`, and the guard's point is not to trust one field.
- A guard in the app only: the app's view is what may be stale, and any client of the API would skip it.
- The phone kept out through `macOnly`: unlike the review it mirrors, with no protection gained.
