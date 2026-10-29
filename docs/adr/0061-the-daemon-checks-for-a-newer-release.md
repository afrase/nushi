# 0061. The daemon checks GitHub for a newer release; the app says so in a toast

Status: accepted, 2026-10-29 (step 424). Builds on [0055](0055-releases-and-the-homebrew-cask.md) (releases) and [0056](0056-the-daemon-restarts-itself-when-idle.md) (the restart after an upgrade).

## Context
The owner: "An update checker that shows a toast or something when a new version is released. Have it check every 2 hours, since we release often and only I and maybe a coworker use it. Auto-update is a later thing."

## Decision
- **The daemon checks**, once per Mac however many windows: `GET api.github.com/repos/afrase/nushi/releases/latest` at start and every 2 hours while Settings › General's "Check for updates" is on (on by default; turned on, it checks at once). No token: the repository is public, and nothing of the user's is sent. The last answer's ETag goes with each ask, so an unchanged release is a free 304. Drafts and pre-releases are never "latest". A failure is a DEBUG line; the next tick asks again.
- **Newer** is semantic versioning's order (a pre-release before its release) of the tag against the daemon's own version (`api.Release`); a build that isn't a release (no version stamped) is never behind. The release's link is built from the tag (`https://github.com/afrase/nushi/releases/tag/<tag>`), not taken from the answer.
- **The app hears it** in Ping's `update` and an `update` event (API 86): the newer release (version, link, published), the latest, and when GitHub last answered. Turned off, the daemon forgets a newer release it found. Check now (the palette's Check for updates, Settings) asks whatever the setting; it brings back a toast dismissed for that version, or says the app is up to date.
- **The toast** sits in the window's bottom right corner, over the details panel's empty bottom in a wide window: not modal, no sound. "Nushi 0.1.17 is available." Installed by Homebrew's cask (Nushi.app in /Applications or ~/Applications, and `Caskroom/nushi` under /opt/homebrew or /usr/local), Copy puts `brew update && brew upgrade --cask nushi` on the clipboard and Release notes opens the release; otherwise Download opens the release's page. × remembers the version (`app.json`): no toast until a newer one. An app already as new as the release (upgraded, its daemon waiting for 0056's restart) shows none. The phone shows nothing.

## Consequences
- An installed `make install` build is stamped with the newest tag it knows: after a release, tags not fetched yet, it is behind by name though not by code, and says so until the next install from fetched tags.
- In a narrow window, without the details panel, the toast covers the composer's right end until dismissed.
- A Homebrew prefix elsewhere than the two usual ones isn't seen: the toast offers Download.

## Alternatives considered
- Each app window asking GitHub: as many asks as windows, and the phone too.
- `brew --prefix` to find Homebrew: a process each launch for a case nobody here has.
- A bar over the app, as the daemon's update bar: the owner asked for a toast, and a bar takes a line from every view until dismissed.
