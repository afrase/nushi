# 0041. Agents speak ACP through acp-go, a library of its own

## Context
[0003](0003-acp-v1-own-client.md) gave Nushi its own small ACP client in `acp/`, because the Go SDKs of the time closed the connection when a 1,024-message queue filled and capped a message at 10 MiB. It was written for Nushi: the types Nushi used, fork and usage by hand with only Nushi's fields, a raw dispatch for the bridges, Nushi's logging inside. The owner wanted it production grade, something strangers could depend on.

## Decision
- `acp/` became `github.com/afrase/acp-go` (MIT, its own repository and CI), and Nushi uses it as anyone would: no Nushi-only shortcuts. All of ACP v1, generated from the pinned schema; the parts the schema marks unstable in its `unstable` package, with the same API.
- Nushi imports `acp "github.com/afrase/acp-go/unstable"`: it uses `session/fork` and a turn's usage, which are unstable in ACP.
- What is Nushi's stays in Nushi: `internal/agentproc` runs an agent's process through the library with Nushi's logging (stderr lines and their caps, exits, what initialize says, the sessions opened, failed and slow calls at WARN, ADR 0038); the fake agent is `internal/acptest`. The Ante and PiG bridges are typed `acp.Agent`s on the library's agent side.
- Nushi depends on a tagged version. A new version is taken with `go get github.com/afrase/acp-go@vX.Y.Z` when Nushi needs it; the library's minor releases follow ACP's schema releases, and its unstable package may change in any of them, so Nushi moves deliberately, not with `@latest`. Working on both at once: a `go.work` beside Nushi (`go work init . ../acp-go`), which git ignores.

## Consequences
- Nushi's daemon code no longer holds JSON-RPC framing or generated types; the library has its own tests (fuzzing, the TypeScript SDK both ways, ACP's conformance kit, leak checks) that Nushi's don't repeat.
- A fix the library needs is made there, released, and taken: two commits, in two repositories.
- `make lint` builds the pinned golangci-lint into `bin/`: `go tool -modfile` refuses to run beside a `go.work`.

## Alternatives considered
- Keeping `acp/` in Nushi: less to release, but nobody else could use it, and its API was shaped by Nushi's shortcuts.
- Switching to another Go SDK: coder's still closes the connection on a full queue and caps messages at 10 MiB; caelis-labs' fails the connection at a queue limit and has no unstable protocol (no fork).
