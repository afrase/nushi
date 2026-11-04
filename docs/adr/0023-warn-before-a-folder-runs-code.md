# 0023. Warn before a folder's own code runs; never refuse

## Context
Claude Code in a terminal shows a trust dialog before it starts in a folder it hasn't been told to trust. An SDK session, which is what claude-agent-acp runs for Nushi, never shows it, and runs what the folder brings anyway: hooks, the `env` block and helper commands (`apiKeyHelper` and the like) in `.claude/settings.json` and `settings.local.json`, its skills' hooks, and its `.mcp.json` servers, approved or not (Claude's permissions docs, "What runs before you trust a folder"). A cloned repository could run code on a chat's first message, or before it. Claude records trust as `projects[<key>].hasTrustDialogAccepted` in `~/.claude.json`, the key being the repository's root (its main checkout for a worktree) or, outside git, the folder, which then covers the folders under it.

## Decision
- Before a chat starts or moves into a folder, the app asks the daemon what the folder would run. When it brings anything and neither Claude's record nor Nushi's covers it, the app shows a card listing each file and exactly what it runs, with "Start anyway" and "Cancel". A folder that brings nothing never asks.
- "Start anyway" is remembered by Nushi, in its own data (`trusted.json`), under Claude's key, so worktrees of that repository and (outside git) the folders under it count too. Nushi reads Claude's trust record and never writes it.
- It's a warning, not a rule: the daemon still starts a chat anywhere it's asked to.
- Git runs with hooks, the fsmonitor, signature checks and lazy fetching (a partial clone's promisor remote) off, and never runs a status inside a submodule, everywhere; the status Nushi runs on its own (the panel's card) also turns off the filter drivers the repository's own config defines. A downloaded (not cloned) folder brings its `.git/config`.

## Consequences
- The card lists what Claude's files say; a plugin the user enabled, or a server in the user's own config, isn't the folder's and isn't listed.
- Opening Changes, and making a worktree (a checkout), still run the repository's own filters, as the user's own git would there; fetching a pull request's head runs its transport config (`core.sshCommand`, `uploadpack`, `credential.helper`, `insteadOf`).
- An older app (before API 37) starts chats without asking.

## Amendment (2026-11-04): a pull request's head is checked where it starts
A chat on a pull request starts in a worktree of its head, which the card's folder (the checkout the user picked) doesn't show. The daemon now checks the new worktree before the agent starts there; when it brings anything nobody trusted, the worktree goes, the app shows the card for the head, and "Start anyway" starts again, for exactly what the card showed at the commit it showed it (a head pushed again between the card and the start is asked about again: a fork can change what a listed hook runs without changing anything listed). A fork's head is an outsider's: no earlier trust counts for it (Claude's is the repository's, which any head would ride on), and "Start anyway" there is for that start only. A head of the repository's own is trusted and remembered as its folder is. An older app (before API 105) gets no card for the head.

## Alternatives considered
- Refusing to start until trusted, or writing Claude's trust record on "Start anyway": both take the decision away from the user or from Claude.
