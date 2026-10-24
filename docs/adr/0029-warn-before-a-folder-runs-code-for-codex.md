# 0029. Warn before a folder's own code runs, for Codex too

## Context
[0023](0023-warn-before-a-folder-runs-code.md) warns before Claude runs what a folder brings. Codex 0.160.1 (read in its source) reads a `.codex` folder in each folder from the project's root down to the session's cwd (for a linked worktree, hooks from the main checkout's), loading those of a trusted project, and records trust as `projects.<path>.trust_level = "trusted"` in its own `config.toml` (`$CODEX_HOME`, else `~/.codex`), the path being the folder, its project root or its repository's main checkout. But codex-acp 2.2.2 starts every session with `projects.<cwd>.trust_level = "trusted"` as an override, so a chat's own folder's `.codex` always loads, even where the user marked it untrusted. That config can start MCP servers, set the environment every command gets (such as `BASH_ENV`), set sandbox and approval settings, turn on plugins, and more; its rules can let commands run without asking; its hooks run once the user trusted each in Codex.

## Decision
- For a Codex chat, the card shows every file that isn't empty in each `.codex` Codex reads for that folder (the project's root down to it, and a worktree's main checkout's), whole (past 256 KB, where it is), as milestone R settled for Claude's skill hooks: Nushi doesn't pick which keys matter. A `config.toml`'s MCP servers and environment show above it, as a summary.
- Codex's record of trust counts as Claude's does. "Start anyway" is kept per agent and per what was shown (`codex:<folder>#<hash of the files>` in `trusted.json`): a folder below, or a file added or changed since, asks again, and a folder trusted for Claude still warns for Codex.
- As in 0023, it warns and never refuses; Nushi never writes Codex's config.

## Consequences
- The card shows what will load, not what Codex would ask about: codex-acp's override means Codex itself never asks.
- An older app asks about Claude's files only (CheckFolder without an agent is the default agent's).
- Codex runs `git status` in the folder each turn with hooks and fsmonitor off but the repository's filter drivers on, as Nushi's Changes view does (0023).
