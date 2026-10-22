# Nushi

A macOS app for running coding agents as chats over the [Agent Client Protocol](https://agentclientprotocol.com), plus a diff viewer. A Go daemon (`nushid`) runs the agents; a Flutter app is the window. While the rebuild runs next to the first build it is called **Nushi Next** ([ADR 0011](docs/adr/0011-nushi-next-identity.md)).

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
make package # a release "Nushi Next.app" with nushid inside (ad-hoc signed)
make install # package, then copy it to ~/Applications
```

The packaged app starts its bundled `nushid` when no daemon is running, and leaves it running when it quits ([ADR 0013](docs/adr/0013-app-starts-its-daemon.md)). With `make run`, start and stop the daemon yourself.

The daemon keeps its socket, token and log in `~/Library/Application Support/Nushi Next/`.

Decisions are in [`docs/adr/`](docs/adr/README.md).
