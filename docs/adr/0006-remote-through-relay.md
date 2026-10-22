# 0006. Remote access later, through an end-to-end encrypted relay

## Status
Proposed; nothing is built.

## Context
The user will want to check on agents from a phone. Opening a port on the Mac is fragile and risky.

## Decision
When remote access is built: the daemon dials out to a relay; the relay only forwards ciphertext; a phone pairs with each daemon by scanning a QR code that carries the daemon's key and a client token. Tailscale is the simpler alternative for people who already run it.

## Consequences
- The API stays transport-agnostic and token-authenticated ([0005](0005-clients-authenticate.md)).
