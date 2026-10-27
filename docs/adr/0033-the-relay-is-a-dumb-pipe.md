# 0033. The relay is a dumb pipe that keeps nothing (replaces 0006)

## Context
A phone has to reach the daemon on a Mac that is often behind a company network, where nothing may listen and only outbound HTTPS gets out. [0006](0006-remote-through-relay.md) proposed a relay; the owner settled the details (`nushi-mobile-research.md`, "Owner decisions"): anyone may run one, the user picks it, and it learns as little as possible.

## Decision
- `nushi-relay` is one static Go binary (`relay/`, `cmd/nushi-relay`). A listener waits at `GET /v1/listen/{id}`, a dialer comes to `GET /v1/dial/{id}`; each is a WebSocket. Once a dialer has sent its first message (the dialer always speaks first), the relay pairs it with the listener waiting on the same id and copies binary messages between them until either side goes. A listener that speaks before it has a dialer is closed; a dialer that finds none within 10 s is closed.
- Only the holder of an id's key listens there. An id is the SHA-256 of a listen key's public half (Ed25519, with a domain tag; the daemon's own, apart from its Noise key). The relay sends a new listener 32 fresh random bytes; it listens only once it answers, within 10 s, the public key and its signature of the bytes and the id. So knowing an id (a revoked phone, anyone who saw a `ws://` URL) is enough to dial it, never to listen. A second listener that proves the key replaces the one waiting: that is the same daemon, back. Phones only dial.
- It knows nothing about who is talking: no accounts, no tokens, no disk, no database. It logs only that it started and fatal errors (Go's HTTP error log, which names client addresses, is discarded). It has no metrics.
- In memory only, caps keep it from being a free bandwidth pipe or something one client can fill: 64 KiB a message, 1 MiB/s a connection after an 8 MiB burst (each message and each ping costs at least 512 bytes), 90 s of silence (pings count), a listener waits an hour at most (it connects again), 16 dialers an id (the id's own listener is never kept out), 1,000 in all. Per client address (an IPv4 address or an IPv6 /64): 200 connections, never more than half of the total, and 2 new ones a second after a burst of 60. Many people can share one company address, so these are generous. Plain connections (not WebSockets, or not yet) count apart: 8 per address, coming at the same rate as WebSockets (the address is the TCP peer's, or behind a proxy the header's once a request has come), and 1,000 in all. New ones that haven't sent a request yet (behind a proxy, whose address isn't known yet) have a budget of 100 and 2 s for their first headers; when the budget or the total is spent, the oldest of them makes way for a new one, else the one idle longest, so a flood of idle or slow sockets can't keep a daemon or a phone out. A later request gets 5 s for its headers, and a connection is closed after 5 s idle between requests. All are flags.
- Those per-address counts are kept under a keyed hash of the address (the key is random each start), never the address, and dropped once the address has no connection and its rate is back. Behind a reverse proxy, `-ip-header` names the header with the client's address; without it the proxy's address is the only one. Of a list header such as `X-Forwarded-For` the relay takes the last entry (or the `-ip-hops`-th from the right, with several proxies appending), never the first: a proxy appends after what the client wrote.
- TLS is optional: built in (`-host`, Let's Encrypt through autocert, the certificate in memory unless `-cert-cache` names a folder), or plain behind a reverse proxy. `ws://` is allowed; the security doesn't rest on it.
- Requests with an `Origin` header (a web page's script) are refused.

## What the relay can still see
- IP addresses of both ends: where the phone is when it checks, and the Mac's (company) egress.
- Rendezvous ids, and the listen keys' public halves: the daemon's long-lived id (one per daemon, so it links every phone connection to that daemon; it changes when a device is revoked) and each one-time pairing id. Ids are random and carry no names. The URL path holds them, so without TLS the networks in between see them too.
- Timing and sizes: when connections open and close, when each message passes and how big it is. That shows when someone works, how long turns run, roughly how much the agent writes, and when an answer comes.
- How many connections a daemon has, and the WebSocket framing.
- The hosting provider (Fly.io, a VPS's host, a TLS-terminating proxy in front) sees the same.

## What it can't
- Anything inside the messages: they are Noise transport messages ([0034](0034-noise-between-phone-and-daemon.md)), encrypted and authenticated end to end. It can't read, change, replay, reorder or inject one without the connection failing.
- Which device connects: a phone's public key travels encrypted inside the handshake.
- The daemon's public key and the pairing secret: they reach the phone through the QR code, never through the relay.

## Consequences
- The relay can drop, delay or refuse traffic (availability is not protected), and can make a daemon do a handshake's work per dial (capped by its own limits and the daemon's).
- Anyone who knows a daemon's id can dial it, which costs the daemon a handshake, and can hold its 16 dialer slots, which keeps its phones out while it does (availability); it can't listen there, so it never gets a phone's dial. Only a paired phone gets past the handshake.
- The proof binds an honest relay. A dishonest one (its operator) can route a dial anywhere; against it only Noise protects, as above.
- Running without `-cert-cache` asks Let's Encrypt for a certificate on every start; frequent restarts hit its rate limits, so a host that restarts often should keep one.

## Amendments
- 2026-10-27: with `-web` and `-origin` the relay also serves the phone's web app, from memory with a strict CSP, and takes a WebSocket from exactly that app's origin; any other `Origin` is still refused (ADR 0054).
