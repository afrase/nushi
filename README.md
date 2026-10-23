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

Decisions are in [`docs/adr/`](docs/adr/README.md).
