# 0113. The relay has the web app built in

Status: accepted, 2026-11-13. Amends [0054](0054-the-phone-is-a-web-app-with-web-push.md) (the relay serves the app from a folder) and [0055](0055-releases-and-the-homebrew-cask.md) (a release's files).

## Context
A release had two files for whoever runs a relay: `nushi-relay` and `nushi-web-X.Y.Z.tar.gz`, unpacked into a folder the relay's `-web` named. Two things to fetch, check and keep at the same version, and a folder whose owner and permissions decide who can change the app's code. The owner expected one binary: "It makes deployment simple. You can put one binary into a docker container".

## Decision
- **A release's relay embeds the app** (`cmd/nushi-relay/web.go`, `//go:embed all:web`). `tools/release.sh` builds the web app, copies it into `cmd/nushi-relay/web`, builds the relays and empties the folder again. The repository keeps that folder with a placeholder only, so every other build (`make relay`, `go build`, the tests, CI) needs no Flutter and has no app: no build tag, one program either way.
- **`-origin` serves it.** The app needs its origin (the CSP, and the one origin whose pages may open a WebSocket), so naming it is what turns the app on. Without `-origin` the relay is the pipe it was (ADR 0033), `-host` alone included: a relay run as before serves what it did before.
- **`-web <folder>` still serves a folder's app** instead, for a build being tried and the web tests; with `-host` its origin is still `https://<host>` unless given. `-origin` on a relay built without the app, and no `-web`, is refused with what to do.
- **No `nushi-web` tarball in a release.** `make relay-web` builds the same relay here.

## Consequences
- The relay's file is about 55 MB instead of 3 (35 MB as its tarball). The fallback fonts (21 MB) are read from the binary's own pages when asked for; the rest is copied into memory at start as before.
- One sha256 covers the relay and the code it serves; nothing on the relay's disk but the binary holds the app. Whoever can replace the binary could always replace the folder: this is fewer things to get wrong, not a new guard.
- A relay updated from a folder setup must drop `-web` from its service, or it keeps serving the old folder (docs/remote.md).

## Alternatives considered
- The web folder inside the relay's tarball: one download, still a folder to place and protect.
- A build tag for the embedding: the tagged file would be compiled and linted only at a release.
- Serving the app whenever `-host` gives an origin: a relay run only as a pipe would start serving code on an update.
