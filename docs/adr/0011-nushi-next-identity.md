# 0011. The rebuild runs as "Nushi Next" beside the first build

Superseded by [0018](0018-the-app-is-nushi.md).

## Context
The POC may still be installed and running on the same Mac.

## Decision
Until the rebuild replaces it, it uses the app name "Nushi Next", bundle ID `com.nushihq.NushiNext` and data folder `~/Library/Application Support/Nushi Next`, so the two never share a socket, data or settings.

## Consequences
- Switching to the plain name later is a rename plus deleting the old folder by hand.
