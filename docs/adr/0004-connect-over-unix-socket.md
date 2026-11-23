# 0004. Connect RPC over a Unix socket, additive changes only

## Context
The app needs typed calls and a stream of events from the daemon. The daemon keeps running while the app updates, so the two can be different versions.

## Decision
- The API is protobuf plus Connect RPC (HTTP/2 cleartext) over a Unix socket in the user's Application Support folder. `buf generate` makes the Go and Dart code, which is committed.
- One server stream carries events; everything else is unary.
- API changes are additive. The handshake (`Ping`) carries a single API version number, bumped when the API grows.
- **An API floor** (amended 2026-11-24; until then an app newer than its daemon showed one blocking screen, then from 0056 only a daemon below API 77 did, and the gates for the rest had no end): the app's `apiFloor` is the API of the newest stable release at least 7 days old, raised in the commit that cuts each stable release. On the Mac a daemon below it gets one blocking "Restart daemon" screen and nothing else, while the pings go on asking it to restart once idle (0056), so the screen clears by itself. The phone is never blocked: below the floor it shows a bar, "Open Nushi on your Mac to update its daemon", and with any older daemon a call it lacks fails with those words; its floor is the one built into the relay's web app (0113), so it moves when the relay is updated. From the floor to the app's own API the app works with the older daemon: a call or field it lacks is gated by a constant named for it, which goes once the floor passes it (`api_floor_test.dart` fails on a gate at or below the floor). An older app on a newer daemon keeps working, since changes are additive, and the daemon keeps no code for older apps (amended 2026-10-24: until then the app hid each feature an older daemon lacked, and the daemon answered apps from before API 23).
- Amended by [0056](0056-the-daemon-restarts-itself-when-idle.md): a daemon at or above the floor that restarts itself when idle gets a bar while it waits, not the screen.
- Amended (API 92): a field or message may be renamed in place, its number and type kept, its old name in its comment. The Mac and the phone speak the binary protobuf codec, where names don't travel, so an older app, phone or daemon reads it as before, both ways. A new field beside the old one would have to be filled twice by the daemon and read with a fallback by the app while an older daemon waits to restart (0056). Names do show in Connect's JSON form, which no client of Nushi's uses.
- No field version tags, revision tables or custom codegen plugins; `buf breaking` (WIRE) runs in lint (amended 2026-11-23).

## Consequences
- A field or method no app uses any more can go; a dropped field's number and name become `reserved`. Removing one an older app still calls needs a new ADR.
- Removed 2026-11-05: `GetGitHubPrompt`, which only apps up to v0.1.14 call; an app that old reaches a newer daemon only after a downgrade, since an update restarts the daemon (0056). proto can't reserve an rpc or a top-level message, so it and its two messages are simply gone.

## Alternatives considered
- gRPC: heavier on the Dart side, no gain.
- JSON over WebSocket: untyped.
