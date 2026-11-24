# 0149. The relay updates itself when asked

Status: accepted, 2026-11-24. Builds on [0113](0113-the-relay-has-the-web-app-built-in.md) (one binary holds the relay and the app) and [0055](0055-releases-and-the-homebrew-cask.md) (a release's files).

## Context
Updating a relay was four steps by hand (docs/remote.md): download a release's tarball and its `.sha256`, check one against the other, install the binary, restart the service. The owner wants it simple; he runs his on a small Linux box.

## Decision
- **A command in the binary**: `nushi-relay -update` (`internal/relayupdate`) asks GitHub for `afrase/nushi`'s latest release, and if it is newer downloads this machine's tarball and its `.sha256`, checks them, takes out the one file, runs it once with `-version`, and renames it over the running binary (its mode and owner kept). `-restart-unit <name>` then runs `systemctl restart <name>`, only after an install. A command, not a script: one static file stays the whole install, nothing is piped to a shell, and no container is needed.
- **Stable only, forward only.** GitHub's latest release, refused if it says draft or pre-release or its tag isn't `vX.Y.Z`; installed only when newer than this relay as semver orders them (a beta moves to its release). A relay not built from a release (`dev`) refuses. Linux on amd64 and arm64 only, as a release builds.
- **Never by itself.** Nothing in the serving relay checks for releases. A timer is the operator's choice (docs/remote.md shows one), opt-in.

## What it trusts
GitHub's answer for `afrase/nushi`, over TLS. The `.sha256` comes from the same release, so it guards the transfer, not the publisher: releases aren't signed. Whoever can publish a release there gets their code run as root on every machine that runs this command: `-update` runs as root and runs the new binary once with `-version` before installing it, and a timer runs the installed one as root again each week. That is more than the relay, which its service runs unprivileged, and more than the phone's app it serves, which holds the phone's key (ADR 0054). So a person runs it, and a timer is opt-in. Signing releases is the step that would let a timer be the default.

## Consequences
- Run as root (the binary is root's, under `/usr/local/bin`); it says so when it can't write the folder.
- A relay whose code may have been changed can't be trusted to update itself: that recovery stays a manual reinstall (docs/remote.md).
- Relays older than this command move by hand once.

## Alternatives considered
- An install script fetched with curl and piped to sh: a second thing to trust, and a shell running what a server sends.
- A container image: an extra runtime on a box that needs one file.
- The relay checking for releases while it serves: an update the owner didn't ask for, and a relay that reaches out to GitHub on its own.
