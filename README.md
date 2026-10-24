# Nushi

A macOS app for running coding agents as chats over the [Agent Client Protocol](https://agentclientprotocol.com), plus a diff viewer. A Go daemon (`nushid`) runs the agents; a Flutter app is the window.

## Requirements

- Go (current stable) and Flutter on `PATH`
- For `make gen`: `dart pub global activate protoc_plugin` and `dart pub global activate connectrpc` (buf runs through `go run`)

## Run

```sh
make run     # starts nushid in the background (if it isn't running), then the app
make stop    # stops nushid
make test    # all tests
make gen     # regenerate the API code after editing proto/
make lines   # hand-written line counts
make package # a release "Nushi.app" with nushid inside (ad-hoc signed)
make install # package, then copy it to ~/Applications
```

The packaged app starts its bundled `nushid` when no daemon is running, and leaves it running when it quits ([ADR 0013](docs/adr/0013-app-starts-its-daemon.md)). With `make run`, start and stop the daemon yourself.

The daemon keeps its socket, token and log in `~/Library/Application Support/Nushi/`. To try a build beside a Nushi that's in use, give both another folder: `NUSHI_DATA=~/Library/Application\ Support/Nushi\ Dev make run` (and the same for `make stop`).

## Agents

"New chat" starts the agent used last; the menu beside it picks another. A chat keeps its agent.

- **Claude**, through `npx --yes @agentclientprotocol/claude-agent-acp@0.94.0`. It uses Claude Code's own login and settings.
- **Codex**, through `npx --yes @agentclientprotocol/codex-acp@2.2.2`, which brings Codex 0.160.1. It uses Codex's own login or config (`$CODEX_HOME`, else `~/.codex`): sign in with `codex login`, or name a provider in `config.toml` (NOTES.md has one for Fireworks). A provider's key comes from the environment, which agents get from your login shell when the app starts the daemon ([ADR 0028](docs/adr/0028-agents-get-the-login-shells-environment.md)). A Codex chat resumes in a terminal with `codex resume <session id>`.

- **Ante**, through Nushi's own bridge (`nushid ante-acp`, [ADR 0030](docs/adr/0030-our-own-bridge-for-ante.md)), which runs an `ante serve --stdio` per session. It needs Ante 0.2.14 or newer (`ante` on `PATH`, or in `~/.ante/bin`) and uses Ante's own settings, providers and sign-in (`~/.ante`, or `$ANTE_HOME`). An Ante chat resumes in a terminal with `ante --resume <session id>`.
- **oh-my-pi**, through `npx --yes -p bun@1.4.3 -p @oh-my-pi/pi-coding-agent@18.12.6 omp --mode acp` (omp needs Bun, which npx brings beside it). It uses omp's own config and keys (`~/.omp`, the environment: `FIREWORKS_API_KEY` for Fireworks). An omp chat resumes in a terminal with `omp --resume <session id>`; Nushi can't delete an omp session's history.

Claude, Codex and oh-my-pi need `npx` (Node) on the login shell's `PATH`. What each agent can do (fork, rewind, steering, questions, the context breakdown, MCP) follows what it reports; a control it lacks isn't shown.

Decisions are in [`docs/adr/`](docs/adr/README.md).
