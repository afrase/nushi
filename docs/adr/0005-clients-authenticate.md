# 0005. Clients authenticate with a token from the start

## Context
A phone may connect later. If the local API trusted the socket's file permissions alone, adding a remote client would mean a redesign.

## Decision
Every request carries a bearer token that the daemon checks. The daemon creates a random token on first start and stores it, mode 0600, in its data folder; the local app reads it from there. The socket also sits in a 0700 folder.

## Consequences
- Remote access needs only a way to hand a client a token (see [0006](0006-remote-through-relay.md)), not a new auth model.
- Same-user processes can read the token; they are outside the threat model.
- Amended by [0024](0024-the-agent-can-read-the-token.md): the agent is a same-user process too, and can read the token.
