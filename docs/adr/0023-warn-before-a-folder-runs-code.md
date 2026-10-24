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
- Opening Changes, and making a worktree (a checkout), still run the repository's own filters, as the user's own git would there.
- An older app (before API 37) starts chats without asking.

## Alternatives considered
- Refusing to start until trusted, or writing Claude's trust record on "Start anyway": both take the decision away from the user or from Claude.
