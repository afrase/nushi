# 0004. Connect RPC over a Unix socket, additive changes only

## Context
The app needs typed calls and a stream of events from the daemon. The daemon keeps running while the app updates, so the two can be different versions.

## Decision
- The API is protobuf plus Connect RPC (HTTP/2 cleartext) over a Unix socket in the user's Application Support folder. `buf generate` makes the Go and Dart code, which is committed.
- One server stream carries events; everything else is unary.
- API changes are additive. The handshake (`Ping`) carries a single API version number, bumped when the API grows.
- An app newer than its daemon shows one blocking "Restart daemon" screen and nothing else; an older app on a newer daemon keeps working, since changes are additive. No per-feature gating in the app, and the daemon keeps no code for older apps (amended in step 64: until then the app hid each feature an older daemon lacked, and the daemon answered apps from before API 23).
- Amended by [0056](0056-the-daemon-restarts-itself-when-idle.md): a daemon that restarts itself when idle (API 77 on) gets a bar while it waits, not the screen.
- No field version tags, revision tables, `buf breaking` or custom codegen plugins.

## Consequences
- A field or method no app uses any more can go; a dropped field's number and name become `reserved`. Removing one an older app still calls needs a new ADR.

## Alternatives considered
- gRPC: heavier on the Dart side, no gain.
- JSON over WebSocket: untyped.
