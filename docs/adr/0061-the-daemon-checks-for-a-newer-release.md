# 0061. The daemon checks GitHub for a newer release; the app says so in a toast

Status: accepted, 2026-10-29. Builds on [0055](0055-releases-and-the-homebrew-cask.md) (releases) and [0056](0056-the-daemon-restarts-itself-when-idle.md) (the restart after an upgrade).

Amended by [0109](0109-update-runs-homebrew.md): where the toast had Copy it has Update, which has the daemon run Homebrew's upgrade; Copy stays for a failure and an older daemon.

## Context
The owner: "An update checker that shows a toast or something when a new version is released. Have it check every 2 hours, since we release often and only I and maybe a coworker use it. Auto-update is a later thing."

## Decision
- **The daemon checks**, once per Mac however many windows: `GET api.github.com/repos/afrase/nushi/releases/latest` at start and every 2 hours while Settings › General's "Check for updates" is on (on by default; turned on, it checks at once). No token: the repository is public, and nothing of the user's is sent. The last answer's ETag goes with each ask, so an unchanged release is a free 304. Drafts and pre-releases are never "latest". A failure is a DEBUG line; the next tick asks again.
- **Refused for its rate, the API isn't the only way** (added 2026-11-11): without a token GitHub allows an address 60 requests an hour, and an office or a VPN is one address, so there the check got "403 Forbidden" through no fault of the user, and the automatic one failed unseen. On a 403 or 429 that is a rate refusal (nothing left of the limit, a `Retry-After`, or GitHub's message says so), and on nothing else (not a 404, not a network's failure), the daemon asks the repository's public pages on `github.com` instead, still with no token and nothing of the user's: `GET github.com/afrase/nushi/releases/latest`, whose redirect's `Location` ends in the tag (read, never followed), or for a Nushi that follows beta versions `releases.atom`, whose entries link to each release. Only a link to this repository's `/releases/tag/<tag>` on that host counts. The API stays first: it is the documented interface and has the free 304. When the pages fail too, the API's refusal is what's said, as "GitHub is limiting requests from this network. Try again in about 12 minutes." (from `x-ratelimit-reset` or `retry-after`; "Try again later." without one). What GitHub was seen to answer: `docs/facts/github.md`.
- **Newer** is semantic versioning's order (a pre-release before its release) of the tag against the daemon's own version (`api.Release`); a build that isn't a release (no version stamped) is never behind. The release's link is built from the tag (`https://github.com/afrase/nushi/releases/tag/<tag>`), not taken from the answer.
- **The app hears it** in Ping's `update` and an `update` event (API 86): the newer release (version, link, published), the latest, and when GitHub last answered. Turned off, the daemon forgets a newer release it found. Check now (the palette's Check for updates, Settings) asks whatever the setting; it brings back a toast dismissed for that version, or says the app is up to date.
- **The toast** sits in the window's bottom right corner, over the details panel's empty bottom in a wide window: not modal, no sound. "Nushi 0.1.17 is available." Installed by Homebrew's cask (Nushi.app in /Applications or ~/Applications, and `Caskroom/nushi` under /opt/homebrew or /usr/local), Copy puts `brew update && brew upgrade --cask nushi` on the clipboard and Release notes opens the release; otherwise Download opens the release's page. × remembers the version (`app.json`): no toast until a newer one. An app already as new as the release (upgraded, its daemon waiting for 0056's restart) shows none. The phone shows nothing.

## Consequences
- An installed `make install` build is stamped with the newest tag it knows: after a release, tags not fetched yet, it is behind by name though not by code, and says so until the next install from fetched tags.
- In a narrow window, without the details panel, the toast covers the composer's right end until dismissed.
- A Homebrew prefix elsewhere than the two usual ones isn't seen: the toast offers Download.

- The feed lists a tag from the moment it is pushed, its release published or not, and the two can't be told apart there: a Nushi that follows beta versions on a limited network may offer a version some minutes before Homebrew's cask has it.

## Alternatives considered
- A token for the check (the user's `gh` login): 5,000 requests an hour, but it sends something of the user's to learn of a public release, which the check never did.
- The pages first, the API never: no documented contract, and no free 304 from `/releases/latest`.
- Each app window asking GitHub: as many asks as windows, and the phone too.
- `brew --prefix` to find Homebrew: a process each launch for a case nobody here has.
- A bar over the app, as the daemon's update bar: the owner asked for a toast, and a bar takes a line from every view until dismissed.
