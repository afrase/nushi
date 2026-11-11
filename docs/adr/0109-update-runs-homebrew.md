# 0109. Update: the daemon runs Homebrew's upgrade

Status: accepted, 2026-11-11. Builds on [0055](0055-releases-and-the-homebrew-cask.md) (the cask), [0061](0061-the-daemon-checks-for-a-newer-release.md) (the check and its card) and [0108](0108-beta-versions.md) (the two casks); amends 0061's and 0108's Copy, and [0056](0056-the-daemon-restarts-itself-when-idle.md)'s idle.

## Context
The card for a newer version offered Copy: the owner pasted `brew update && brew upgrade --cask nushi` into a terminal for every release, several a week, and wants never to run brew by hand. 0108 turned down an updater of Nushi's own (a new thing that writes programs, with signing and rollback to get right) because Homebrew already does it; so Nushi asks Homebrew.

## Decision
- **An Update button on the card**, when Homebrew installed the app and its cask has the version (`caskWith`) and the daemon knows how (API 115). It calls `InstallUpdate`, whose request is empty: the client names no cask, path or version. Mac only: in `macOnly`, and the handler checks for the Mac's socket.
- **The daemon picks the cask and runs a fixed command** (`internal/homebrew`): `nushi@beta` if a Caskroom has its folder, else `nushi`, and only when the daemon itself runs from `Nushi.app` in `/Applications` or `~/Applications` (a build run from elsewhere never has Homebrew replace the installed app). Then `<prefix>/bin/brew update` and `<prefix>/bin/brew upgrade --cask <cask>`, the prefix being the one whose Caskroom has the cask: no shell, nothing from GitHub's answer or the request on the command line. Its environment is the login shell's (as agents get) with `NONINTERACTIVE=1`, `HOMEBREW_NO_ASK=1` and no hints or color; no terminal (Homebrew 7 asks before an upgrade only on one), a session of its own (no chat's process group), 15 minutes at most, the last 64 KB of output kept. One install at a time.
- **How it goes is in `UpdateCheck`**, published as the update event: `installing`, `install_error`, `installed`. The card says "Updating to Nushi X…" with the spinner and a disabled button. A failure shows as a line or two (brew's last `Error:` line; where to allow it when the output says macOS refused), with Retry, Copy (as before) and Release notes; the end of brew's output goes to `nushid.log`.
- **A run that leaves the cask without the version is a failure too** ("Homebrew doesn't have 0.29.0 yet. Try again in a few minutes."): a release is on GitHub some minutes before the workflow has pushed its cask. The daemon looks for `Caskroom/<cask>/<version>`; the version from GitHub's answer is used for that look only, and only if it can be a folder's name.
- **Homebrew quits the app and opens the new one; the daemon doesn't.** `uninstall quit:` quits Nushi, and since Homebrew 5.1.12 (`cask/upgrade.rb`, `reopen_apps_after_upgrade`, May 2026) an upgrade reopens with `open -b` each app it managed to quit; `brew update` runs first, so the brew that upgrades is current. The daemon is brew's parent, not the app, so it outlives the quit; an install holds 0056's restart (the new app asks for it as soon as it's open, before brew has finished). When Homebrew couldn't quit the app, the card of the app still running says "Nushi X is installed. Quit Nushi and open it again."
- **No updater for a zip or Linux install**, no setting, no progress: those keep Download.

## Consequences
- **Unverified, since no test here may run Homebrew or the installed app:** brew runs as "Nushi Daemon"'s child, so macOS's privacy controls judge the daemon, and each release is a new program to them (ad hoc signing, 0055).
  - *App Management* (replacing an app in /Applications) may prompt for Nushi Daemon or refuse it. Homebrew then deletes and reinstalls the app instead of changing it in place; if that fails too, the card says where to allow it (System Settings › Privacy & Security › App Management). The words matched ("App Management", "Operation not permitted") are Homebrew's source's and the system's, not ones seen.
  - *Automation* (the Apple event that quits Nushi): the helper's Info.plist has no `NSAppleEventsUsageDescription`, so macOS likely refuses the event without asking. Homebrew then waits 10 s, warns, upgrades with the app still open and reopens nothing: the "installed" card is for that. If that's what happens every time, the fix is the usage description (a prompt per release) or the app quitting and reopening itself once the daemon says `installed`.
- A Homebrew prefix elsewhere than the two usual ones isn't seen, as before (0061): Download.
- A daemon stopped mid-install (a crash, Restart now) leaves brew running without anyone reading it; the next daemon knows nothing of it.

## Alternatives considered
- The app running brew: Homebrew quits the app, taking brew with it mid-upgrade.
- A terminal opened on the command: still a terminal to watch and close.
- Passing the cask or version in the request: a caller's word on a command line for nothing; the daemon can see both.
