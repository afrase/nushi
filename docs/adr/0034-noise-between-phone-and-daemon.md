# 0034. Noise between the phone and the daemon; pairing by QR code (replaces 0006)

## Context
A phone talks to the daemon through a relay anyone may run ([0033](0033-the-relay-is-a-dumb-pipe.md)), so everything must be encrypted and authenticated end to end. The owner settled it ("Owner decisions" in `nushi-mobile-research.md`): a standard Noise pattern, unmodified, `flynn/noise` in the daemon and Dart on the phone (no Go there), checked against the standard test vectors; no paid review, an adversarial review by subagents instead. This ADR is what that review checks against.

## Decision
**Patterns.** `Noise_IKpsk1_25519_ChaChaPoly_BLAKE2s` to pair, `Noise_IK_25519_ChaChaPoly_BLAKE2s` after (`noiseconn/`, `packages/noise`). The phone is always the initiator.
- IK because the phone knows the daemon's static key beforehand (from the QR code), so it is pinned from the first message: a relay can't swap it. The phone's static key travels encrypted in the first message, so the relay never sees which device connects. One round trip; both sides' ephemeral keys give forward secrecy.
- `psk1` puts the QR's one-time secret into the first message: the daemon rejects a phone without it before answering, and stays waiting for the right one.
- Not XX (it would send the daemon's key, which the phone already has, and take a third message); not KK (the daemon would have to learn which device it is before the handshake, so a device id would go in the clear); nothing home-made on top of the spec.
- Both handshake payloads are empty, so no data goes out before the handshake ends (no 0-RTT data to replay).
- The prologue is `nushi-remote/1`, a zero byte, and the rendezvous id, so a handshake meant for one id fails on another.

**The channel.** Each WebSocket message is one Noise message (at most 65,535 bytes). Nonces are Noise's 64-bit counters, implicit and in order; a message that fails to decrypt (changed, replayed, reordered, or after one that was dropped) ends the connection. Each direction rekeys (Noise's `REKEY`) after every 4,096 messages. Inside, HTTP/2 carries the existing Connect API unchanged: the daemon serves it on the channel as a `net.Conn`; the phone's generated client runs over `ClientTransportConnection.viaStreams`.

**Keys.**
- The daemon's static key and its listen key are made once and kept in `remote-key.json` (0600) in the data folder, with the listen keys of ids given up after a revoke that some device still needs. The listen key (Ed25519) only proves to the relay that the daemon may listen at its rendezvous id, the key's hash (0033). Deleting the file means pairing every phone again.
- A device's key is made and kept on the device; the daemon keeps only its public key, in `devices.json` (0600) with its name and the times it paired and was last seen.
- Nushi never reads the agents' or the user's credentials.

**Pairing.**
1. Settings → Remote access → "Pair a phone". The daemon makes a one-time listen key (its hash is the pairing id) and a 32-byte secret, waits at the relay on that id for 5 minutes, and the Mac shows a QR code: `nushi://pair?r=<relay URL>&i=<pairing id>&k=<daemon's public key>&s=<secret>`. It goes camera to screen, never through the relay.
2. The phone makes its key and runs `IKpsk1` on the pairing id, then sends its name in its first transport message. The first handshake that completes with the secret uses the secret and the id up, whatever follows: if no name comes, the pairing ends and the Mac offers a new code (the user's choice). A wrong secret or junk doesn't use it up.
3. Both screens show a six-digit code from the handshake hash. The Mac shows the device's name and the code, with Allow and Deny, whoever started the pairing. The user must check the phone shows the same code: that is what stops someone who saw the QR code and connected first (the real phone then shows no code at all).
4. The phone gives up on its code after 150 s with no answer. On Allow the daemon stores the device and sends its long-lived rendezvous id inside the channel (it is never in the QR code); the same channel then carries the API. On Deny, or no answer within 2 minutes, it sends a refusal and closes.

**Later connections.** The phone dials the daemon's id and runs `IK`. The daemon answers only a static key in `devices.json`; anything else gets no answer. A device counts as connected (and its last-seen time moves) only once its first transport message decrypts.

**Revoking** a device removes it from `devices.json` and closes its connections at once; its key then gets no answer. The daemon also moves to a new rendezvous id (a new listen key), which the revoked device never learns. The other devices learn it through the API (`Remote.rendezvous`, which the phone keeps); the daemon still waits at the old id for them alone, until each has connected at the new one, 30 days at most (a phone that hasn't by then pairs again). Turning remote access off closes the relay link and every remote connection.

**A paired device is a full client**, like the Mac app ("Owner decisions": no device modes): chats, permission answers, and terminals too, which amends [0022](0022-the-daemon-owns-terminals.md). Except the Mac's own calls: a device's channel gets "permission denied" for SetRemote, StartPairing, ConfirmPairing and RevokeDevice, so only the Mac (the local socket and its token) pairs, revokes or moves remote access. An agent in a permissive mode already runs anything the phone asks for, so leaving terminals out would protect nothing; the agent's own mode stays the only permission control ([0007](0007-harness-owns-permissions.md)).

## Threat model
What a paired device gets is code execution as the user on the Mac. Everything below is about who can get that, or read what flows.

| Who | Can | Can't |
|---|---|---|
| The relay, its host, or the networks in between (passive or active) | see addresses, rendezvous ids, timing and sizes (0033); drop, delay or refuse traffic; make the daemon do a handshake's work per dial | read, change, replay, reorder or inject a message; pose as the daemon (its key is pinned from the QR code) or as a phone (the daemon answers only known keys); pair a phone (no secret); tell which device connects; the networks in between: listen at an id they see (an honest relay asks for its listen key) |
| Someone who sees or photographs the QR code within its 5 minutes | connect first and get a confirm prompt on the Mac, under any name; with the path as well (the relay, or ws://), drop the real phone's name and use the pairing up | get in without the user pressing Allow while the phone shows another code, or no code; try for a code that matches the real phone's (one handshake per pairing: a one-in-a-million chance) |
| Someone with a used or expired QR code | nothing: the id and secret are used up | |
| A revoked device | dial the old id while another device hasn't moved from it yet: a handshake's work each time, and while it holds the id's dialer slots, that device is kept out (availability) | learn the new id; listen in the daemon's place (no listen key), so get a phone's dial; get an answer, or keep a connection |
| Another relay user | share the relay's caps | reach this daemon's ids without knowing them (hashes of random keys); listen at them even knowing them |
| A stolen phone, unlocked | everything a paired device can, until revoked on the Mac; leave something behind through a terminal or an agent (code execution as you), which revoking doesn't undo | pair another device, revoke the owner's, or move remote access to another relay (the Mac's calls) |
| Someone who gets the phone to scan a QR code of their own (forged) | have the phone pair with their daemon, and read what the user then types into it | reach the user's Mac: the real daemon answers only its own keys (the phone app is to show which Mac it is paired with) |
| Same-user processes on the Mac, the agent included | read the daemon's key and devices file, as they can read the token ([0024](0024-the-agent-can-read-the-token.md)); pair a device through the token (the Mac app still shows Allow and Deny) | (out of scope, as for the local token) |

Also outside what this protects:
- Metadata (0033's list) and availability.
- A leaked daemon key lets its holder pose as the daemon to phones and, through IK's key-compromise impersonation, as a paired phone to the daemon: delete `remote-key.json` and pair again.
- No post-quantum key exchange: X25519 only, so traffic recorded now could be read by a future quantum computer.
- Protecting the device key on the phone (Keychain, app lock) is the phone app's job, still to come.
- The code's correctness: Noise is checked against cacophony's and snow's vectors in both implementations, and Go against Dart; the pairing and channel code around it is new.

## Consequences
- Remote access is off until turned on; while on, the daemon holds one waiting connection at the relay per id it waits at (its own, and after a revoke the old one until the other phones have moved), and nothing listens on the Mac.
- A phone newer than the daemon will need the usual "Update Nushi on the Mac"; the protocol carries a version in its prologue (`/1`) for a later change.

## Amendments
- 2026-10-27: the phone is a web app on the Home Screen with Web Push from the daemon (ADR 0054): pairing by a link whose parameters are in the fragment (the QR code is unchanged), the device key raw in IndexedDB (script on the app's origin can take it; use the web app only from a relay you run), and a device's own calls for its push subscription and open chat. The Noise protocol is unchanged.
