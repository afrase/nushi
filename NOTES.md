# Notes

## Line counts

Hand-written, without tests or generated code (`make lines`). Packages are counted apart from the app.

| Step | Go | Dart app | Dart packages |
|---|---|---|---|
| 1. Skeleton | 114 | 95 | 131 |

## ACP quirks

## Decisions to revisit

- Connect for Go is v1 (`connectrpc.com/connect` v1.21), not v2: v1 is what the Dart generator's docs and the POC used, and nothing here needs v2.
- `http2` for Dart stays on 2.x: `connectrpc` 2.0.1 doesn't resolve with `http2` 3.x.
- The app runs without the macOS App Sandbox, so it can reach the daemon's socket in Application Support.

## Security notes to look at

- The client token (`token`, mode 0600) sits next to the socket in a 0700 folder; any process running as you can read it ([ADR 0005](docs/adr/0005-clients-authenticate.md)).

## Working notes

- Screenshots of the app window are only current while the window is in front: macOS stops Flutter drawing an occluded window.
