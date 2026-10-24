# 0033. The relay is a dumb pipe that keeps nothing (replaces 0006)

## Context
A phone has to reach the daemon on a Mac that is often behind a company network, where nothing may listen and only outbound HTTPS gets out. [0006](0006-remote-through-relay.md) proposed a relay; the owner settled the details (`nushi-mobile-research.md`, "Owner decisions"): anyone may run one, the user picks it, and it learns as little as possible.

## Decision
- `nushi-relay` is one static Go binary (`relay/`, `cmd/nushi-relay`). A listener waits at `GET /v1/listen/{id}`, a dialer comes to `GET /v1/dial/{id}`; each is a WebSocket. Once a dialer has sent its first message (the dialer always speaks first), the relay pairs it with one waiting listener on the same id and copies binary messages between them until either side goes. A listener that speaks before it has a dialer is closed; a dialer that finds none within 10 s is closed.
- It knows nothing about who is talking: no accounts, no tokens, no disk, no database. It logs only that it started and fatal errors (Go's HTTP error log, which names client addresses, is discarded). It has no metrics.
- In memory only, caps keep it from being a free bandwidth pipe: 64 KiB a message, 1 MiB/s a connection after an 8 MiB burst (each message costs at least 512 bytes), 90 s of silence (pings count), 16 connections an id, 1,000 in all. All are flags.
- TLS is optional: built in (`-host`, Let's Encrypt through autocert, the certificate in memory unless `-cert-cache` names a folder), or plain behind a reverse proxy. `ws://` is allowed; the security doesn't rest on it.
- Requests with an `Origin` header (a web page's script) are refused.

## What the relay can still see
- IP addresses of both ends: where the phone is when it checks, and the Mac's (company) egress.
- Rendezvous ids: the daemon's long-lived id (one per daemon, so it links every phone connection to that daemon) and each one-time pairing id. Ids are random and carry no names. The URL path holds them, so without TLS the networks in between see them too.
- Timing and sizes: when connections open and close, when each message passes and how big it is. That shows when someone works, how long turns run, roughly how much the agent writes, and when an answer comes.
- How many connections a daemon has, and the WebSocket framing.
- The hosting provider (Fly.io, a VPS's host, a TLS-terminating proxy in front) sees the same.

## What it can't
- Anything inside the messages: they are Noise transport messages ([0034](0034-noise-between-phone-and-daemon.md)), encrypted and authenticated end to end. It can't read, change, replay, reorder or inject one without the connection failing.
- Which device connects: a phone's public key travels encrypted inside the handshake.
- The daemon's public key and the pairing secret: they reach the phone through the QR code, never through the relay.

## Consequences
- The relay can drop, delay or refuse traffic (availability is not protected), and can make a daemon do a handshake's work per dial (capped by its own limits and the daemon's).
- Anyone who knows a daemon's id can take its waiting connection, but only by sending a message: the daemon then fails the handshake and waits again at once. Only a paired phone gets past the handshake.
- Running without `-cert-cache` asks Let's Encrypt for a certificate on every start; frequent restarts hit its rate limits, so a host that restarts often should keep one.
