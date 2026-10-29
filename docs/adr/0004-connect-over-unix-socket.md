# 0004. Connect RPC over a Unix socket, additive changes only

## Context
The app needs typed calls and a stream of events from the daemon. The daemon keeps running while the app updates, so the two can be different versions.

## Decision
- The API is protobuf plus Connect RPC (HTTP/2 cleartext) over a Unix socket in the user's Application Support folder. `buf generate` makes the Go and Dart code, which is committed.
- One server stream carries events; everything else is unary.
- API changes are additive. The handshake (`Ping`) carries a single API version number, bumped when the API grows.
- An app newer than its daemon shows one blocking "Restart daemon" screen and nothing else; an older app on a newer daemon keeps working, since changes are additive. No per-feature gating in the app, and the daemon keeps no code for older apps (amended 2026-10-24: until then the app hid each feature an older daemon lacked, and the daemon answered apps from before API 23).
- Amended by [0056](0056-the-daemon-restarts-itself-when-idle.md): a daemon that restarts itself when idle (API 77 on) gets a bar while it waits, not the screen.
- Amended (API 92): a field or message may be renamed in place, its number and type kept, its old name in its comment. The Mac and the phone speak the binary protobuf codec, where names don't travel, so an older app, phone or daemon reads it as before, both ways. A new field beside the old one would have to be filled twice by the daemon and read with a fallback by the app while an older daemon waits to restart (0056). Names do show in Connect's JSON form, which no client of Nushi's uses.
- No field version tags, revision tables, `buf breaking` or custom codegen plugins.

## Consequences
- A field or method no app uses any more can go; a dropped field's number and name become `reserved`. Removing one an older app still calls needs a new ADR.

## Alternatives considered
- gRPC: heavier on the Dart side, no gain.
- JSON over WebSocket: untyped.
