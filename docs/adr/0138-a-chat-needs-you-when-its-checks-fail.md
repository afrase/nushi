# 0138. A chat needs you when its pull request's checks fail

Status: accepted, 2026-11-20. Amended by [0140](0140-what-a-chats-pull-requests-ask-of-github.md): the states are the rows' items, every 5 minutes while the window isn't in front.

## Context
A chat's pull request fails its checks after the agent's turn has ended, often while another chat shows. The sidebar's red dot says it, but nothing asks for the user. Claude's Auto-fix acts on a failure by itself; Nushi won't (issue #86): a fix costs money, and a failing log is others' text. Watching from the daemon would reach GitHub on its own, which ADR 0045 rules out.

## Decision
- The app judges it, from the chats' states it asks for anyway (`PullStates`: GetGitHubStates, one query a host each minute, quietly), now kept running for the whole app rather than only while the sidebar shows. No call of its own.
- The states say which commit the checks are of (`GitHubItem.checks_oid`, the head's oid beside its rollup; API 129). A failure is a pull request and that commit (`<node id>@<oid>`).
- A failure the user hasn't acted on makes the chat need you (its phase `waiting`, after a turn or background work, before the rest), with the amber dot, the Dock's badge and the project rail's count, and a bar over the composer: "Checks failed on #n", **Ask to fix** and a ✕ (Dismiss).
- Ask to fix puts each failed check's card in the chat's box, as Fix checks does (the same cards, with what the user set them to ask); nothing is sent. Ask to fix, Dismiss and the PR widget's Fix checks each mark the failure seen (`checksSeen` in `app.json`, by chat). The same failure stays quiet on every ask after; one on a later commit flags the chat again. A failure no longer failing takes the flag away.
- A chat first seen while its checks fail isn't flagged for that failure, so nothing old lights up after an update. Nor is a pull request linked to a chat later, for what fails as its state is first known: each pull request seen is kept with its failure, or with none (`<node id>@`), so a later failure of it is new. A daemon before API 129 says no commit, and nothing is flagged.
- No notification: the badge counts it, and the dot says it.

## Consequences
- A re-run that fails again on the same commit doesn't flag it again; a push does.
- The states are asked for while the app runs even with the sidebar hidden: the same one query a minute the sidebar asked for.
- Only the Mac's app judges it: the phone doesn't flag, and a failure while the app is closed shows when it next asks.

## Amendment (2026-11-25): a cancelled check

A cancelled check is its own kind (githubapi.KindOf, API 148). Checks that fail only because some were cancelled still flag the chat, since GitHub's merge gate holds them back, but the bar says "A check was cancelled on #n" with a grey stop sign and no Ask to fix: nothing in them failed for the agent to fix. A cancel acted on is remembered as a cancel (`<id>@<commit>:cancelled`), so a re-run on the same commit that really fails flags the chat again: the user was told only of a cancel.
