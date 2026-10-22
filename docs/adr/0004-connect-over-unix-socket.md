# 0004. Connect RPC over a Unix socket, additive changes only

## Context
The app needs typed calls and a stream of events from the daemon. The daemon keeps running while the app updates, so the two can be different versions.

## Decision
- The API is protobuf plus Connect RPC (HTTP/2 cleartext) over a Unix socket in the user's Application Support folder. `buf generate` makes the Go and Dart code, which is committed.
- One server stream carries events; everything else is unary.
- API changes are additive only. A newer app treats a method an older daemon lacks (`unimplemented`) as "feature unavailable". The handshake (`Ping`) carries a single API version number, bumped when methods are added.
- No field version tags, revision tables, `buf breaking` or custom codegen plugins.

## Consequences
- Removing or renaming a field or method needs a new ADR.

## Alternatives considered
- gRPC: heavier on the Dart side, no gain.
- JSON over WebSocket: untyped.
