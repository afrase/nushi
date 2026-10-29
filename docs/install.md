# Installing Nushi

Nushi runs on a Mac with Apple silicon and macOS 13 or later. Linux and Windows aren't supported yet: the daemon uses macOS's keychain, sandbox and launchd. The relay runs anywhere ([Remote access](remote.md)).

## With Homebrew

From the owner's Homebrew tap ([ADR 0055](adr/0055-releases-and-the-homebrew-cask.md)):

```sh
brew install --cask afrase/tap/nushi
brew upgrade --cask nushi              # a newer release
brew uninstall --cask nushi            # the app; chats' data stays
brew uninstall --zap --cask nushi      # the app and Nushi's data
```

Releases are signed ad hoc, not notarized. The cask clears macOS's quarantine flag, so installing from the tap stands in for Gatekeeper's check.

## Without Homebrew

1. Download `Nushi-X.Y.Z.zip` and its `.sha256` from [Releases](https://github.com/afrase/nushi/releases).
2. Check it: `shasum -a 256 -c Nushi-X.Y.Z.zip.sha256`.
3. Unzip it, move Nushi.app to Applications and open it.
4. macOS refuses the first time. Go to System Settings › Privacy & Security and click Open Anyway.

## Updates

The daemon asks GitHub for the latest release when it starts and every 2 hours, with no token ([ADR 0061](adr/0061-the-daemon-checks-for-a-newer-release.md)). A newer one shows as a small card in the window's bottom right corner ("Nushi 0.1.17 is available."):

- **Copy** puts `brew update && brew upgrade --cask nushi` on the clipboard, when Homebrew installed the app; **Release notes** opens the release.
- **Download** opens the release's page, when Homebrew didn't install it.
- **×** hides the card until a newer release.

Settings › General › Updates turns the check off, and has Check now. The palette's Check for updates does the same.

## Upgrading

Upgrading quits the app and opens the new one. The daemon keeps running, and its chats with it. It restarts into the new version by itself once nothing would be lost:

- no chat has a turn running or waiting on you;
- nothing is queued;
- no terminal runs a command.

Until then a bar says "Nushi will update its daemon when the chats are idle", with what it waits for (each a link to its chat) and Restart now. Chats reopen where they were on their next message; terminals sitting at their prompt close.

Each release is a new program to macOS. After an upgrade, a Jira token (and a GitHub token you pasted) needs your OK once more: click Allow…, then Always Allow in macOS's prompt ([Jira](jira.md)). gh's own login isn't affected.

## Uninstalling

Uninstalling quits the app. The daemon stops by itself within about a minute once the app is gone, also when you drag it to the Trash. Start at login's item goes with the app.

Chats' data stays in `~/Library/Application Support/Nushi`. **`--zap` deletes it**:

- Nushi's copies of every chat's transcript;
- settings, trust answers, remote access keys and paired devices;
- the adapters and the logs;
- the app's preferences.

It doesn't touch the agents' own history (`~/.claude`, `~/.codex`, `~/.ante`, `~/.omp`, `~/.pig`): those chats still resume in a terminal. The keychain's "Nushi Jira" and "Nushi GitHub" items stay too. Remove the sites in Settings first, or delete them in Keychain Access.

## The daemon

Nushi, an agentic development environment (ADE), is two programs: a Go daemon, `nushid`, that runs the agents, and a Flutter app that is the window.

- The packaged app carries `nushid` in `Contents/Helpers/Nushi Daemon.app`, a background-only app. It starts it when no daemon is running, and leaves it running when it quits ([ADR 0013](adr/0013-app-starts-its-daemon.md), [ADR 0036](adr/0036-the-daemon-is-a-background-helper-app.md)).
- Settings › Start at login also starts it at login.
- A daemon whose app is deleted stops within about a minute. One whose app is replaced (an upgrade, `make install`) keeps running until it restarts.
- Settings › Logs & advanced shows the app's version and the running daemon's. `nushid -version` in the helper app says the same.

## Data and logs

The daemon keeps its socket, token and log in `~/Library/Application Support/Nushi/`:

- `nushid.log`, rotated at 10 MB, with two older copies;
- `app.log`, for what the app logged while the daemon didn't answer.

Settings › Logs & advanced reveals them, and turns on debug lines (or set `NUSHI_LOG=debug`). One chat's lines are `grep 'chat=<id>' nushid.log`. [ADR 0038](adr/0038-logs-you-can-debug-from.md) says what is logged and what never is.

Everything Nushi writes outside its data folder, and why, is in [What Nushi changes outside its data folder](user/outside-the-data-folder.md).
