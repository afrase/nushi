# 0037. Agents are found, not fetched: adapters set up on request from our own lockfile, run with the user's own CLIs; no npx

Supersedes [0003](0003-acp-v1-own-client.md)'s "npx runs the Claude adapter" and every earlier note of starting agents through npx (milestones S and T, step 101).

## Context
A chat's first start ran `npx --yes -p <pinned package>`: it downloaded and ran code from npm with no question asked. Only the top-level package was pinned; npx resolved the rest at whatever versions npm had that day, into the user's npx cache (about 330 MB per adapter). Claude's adapter ran the Agent SDK's own Claude Code (2.1.303), not the user's (2.1.310), Codex's adapter its own Codex, and oh-my-pi came with a Bun of its own, though the user had never installed omp. The owner wants the opposite: no side effects unless asked, and their own agent CLIs, never a copy Nushi brought.

## Decision
- **Found, read-only.** The daemon finds each agent's CLI on the login shell's `PATH` (Ante also where its installer puts it), with its version, and whether it's signed in when the CLI tells cheaply (`claude auth status`). Each CLI runs under `sandbox-exec` with file writes (but `/dev/null`) and the network denied, so finding agents can't change anything: `codex --version` otherwise writes its PATH aliases. Nushi never reads credentials.
- **Set up on request.** An agent whose ACP side is an npm package (Claude's `claude-agent-acp`, Codex's `codex-acp`) shows "Set up" in Settings › Agents, which says what it downloads, how big, and where. One press runs `npm ci` into `<data>/agents/<agent>` from a lockfile kept in the repository (`internal/<agent>/adapter`), so every transitive version and its integrity hash is pinned. Optional dependencies are left out (the Agent SDK's Claude Code, codex-acp's Codex: prebuilt binaries per platform), install scripts don't run (none of the packages has one), npm runs under the sandbox with writes allowed only in `agents/`, with a cache of its own removed after and no logs. Update installs the pinned version when Nushi pins a newer one; Remove deletes the folder. The agent's awake chats sleep before its adapter changes under them.
- **The user's CLIs.** The adapter runs under the Node on `PATH` with `CLAUDE_CODE_EXECUTABLE` (Claude) or `CODEX_PATH` (Codex) set to the CLI found; oh-my-pi is the user's `omp` under the user's Bun; Ante runs through the bridge ([0030](0030-our-own-bridge-for-ante.md)). An agent not installed isn't offered for a new chat; one not set up is shown dimmed, with Set up. A start that fails with a CLI version Nushi wasn't tested with says which versions it was.
- **No npx** anywhere at run time; `internal/npx` is gone. Node (and npm, to set up) must already be installed; Nushi says so when it isn't, and doesn't install it.

## Consequences
- Nothing is downloaded until asked; Claude's adapter is 9 MB to download and 73 MB on disk (was about 324 MB in npx's cache), Codex's 2 MB and 19 MB (was 335 MB).
- Updating an adapter is a change in the repository: its `package.json`, then `make adapters` for the lockfile and the sizes, then testing with the user's CLI versions.
- A newer CLI than the adapter was tested with runs anyway; if it breaks the adapter, the start error says so. Codex runs through `codex.js`, the Node launcher npm installs for `codex`, as it does in a terminal.
- After the change every user sets up Claude and Codex once (existing chats reopen once their agent is set up). The old npx cache is the user's to delete.
- The user's npm settings (a registry, a proxy) apply to the install, which is what a work Mac behind a proxy needs.

## Alternatives considered
- Keep npx with a pinned version: unpinned transitive versions, the user's cache, and no question asked.
- Bundle the adapters in the app: every user carries both whether they use the agent or not, and an update needs a new app.
- `npm install` without a lockfile: transitive versions float again.
- Pointing codex-acp at Codex's native binary inside the user's npm package rather than at the `codex` on `PATH`: saves the 14 MB launcher, but reaches into how Codex is packaged, and isn't "the CLI found".
