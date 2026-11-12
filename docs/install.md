# Installing Nushi

Nushi runs on a Mac with Apple silicon and macOS 13 or later, and on Linux ([below](#on-linux)). Windows isn't supported yet. The relay runs anywhere ([Remote access](remote.md)).

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

## On Linux

Nushi runs on x86_64 and arm64 Linux ([ADR 0104](adr/0104-the-app-runs-on-linux.md)) with:

- glibc 2.34 or later (Ubuntu 22.04, Debian 12, Fedora 35, RHEL 9 and later);
- GTK 3, which every desktop has;
- a Secret Service keyring (GNOME Keyring, KWallet, KeePassXC) for a Jira or GitHub token;
- bubblewrap (`bwrap`) to set up an agent's adapter (Codex's), whose install runs in its sandbox; on Ubuntu, AppArmor must allow unprivileged user namespaces (`kernel.apparmor_restrict_unprivileged_userns=0`);
- an emoji font (Noto Color Emoji) for emoji, and enchant 2 with a Hunspell dictionary for spelling.

From [Releases](https://github.com/afrase/nushi/releases), download `nushi-X.Y.Z-linux-amd64.tar.gz` (or `-arm64`) and its `.sha256`, then:

```sh
sha256sum -c nushi-X.Y.Z-linux-amd64.tar.gz.sha256
tar -xzf nushi-X.Y.Z-linux-amd64.tar.gz
nushi/install.sh
```

`install.sh` puts Nushi in `~/.local/opt/nushi`, and its menu entry and icon in `~/.local/share` (nothing outside your home, no root). Open Nushi from your applications. A newer release installs the same way, over the old one. `~/.local/opt/nushi/install.sh --uninstall` removes it, with Start at login's entry; the data folder stays.

On Linux:

- Pages (an HTML or PDF preview, a browser tab) open in your default browser when you click Open, not inside Nushi, and a diagram shows its source. Ubuntu's Firefox and Chromium are snaps, which can't read hidden folders in your home, so a scratch chat's page (in the data folder) doesn't open in them; a page in a project does.
- The window has your desktop's own title bar.
- Shortcuts take Ctrl where the Mac's take ⌘ (Ctrl+K for the palette, Ctrl+N for a new chat), as the palette and tooltips show them; Ctrl+Q quits. In a terminal, Ctrl+Shift+C and Ctrl+Shift+V copy and paste, and Ctrl with a letter goes to the shell.
- Start at login is an autostart entry, which your desktop session starts as you log in.

## Updates

The daemon asks GitHub for the latest release when it starts and every 2 hours, with no token ([ADR 0061](adr/0061-the-daemon-checks-for-a-newer-release.md)). A newer one shows as a small card in the window's bottom right corner ("Nushi 0.1.17 is available."):

- **Update** installs it, when Homebrew installed the app: the daemon runs `brew update && brew upgrade --cask nushi` ([ADR 0109](adr/0109-update-runs-homebrew.md)). The card says "Updating to Nushi 0.1.17…" until Homebrew quits the app and opens the new one. **Release notes** opens the release.
- If it fails, the card says why, with **Retry**, **Copy** (the same command on the clipboard, for a terminal) and Release notes; the end of Homebrew's output is in `nushid.log`. "Homebrew doesn't have 0.1.17 yet" means the release is out but its cask isn't: Retry in a few minutes. If macOS refused, allow Nushi Daemon in System Settings › Privacy & Security › App Management.
- If the card says "Nushi 0.1.17 is installed. Quit Nushi and open it again.", Homebrew couldn't quit the app: do that.
- **Download** opens the release's page, when Homebrew didn't install it (and on Linux).
- **×** hides the card until a newer release.

Settings › General › Updates turns the check off, and has Check now. The palette's Check for updates does the same.

### Beta versions

A beta is a version to try before its release, such as 0.29.0-beta.1 ([ADR 0108](adr/0108-beta-versions.md)). The tap has a second cask that follows them, and each release that passes them:

```sh
brew uninstall --cask nushi && brew install --cask afrase/tap/nushi@beta   # follow betas; chats' data stays
brew uninstall --cask nushi@beta && brew install --cask afrase/tap/nushi   # back to releases only
```

There's no setting. A Nushi the beta cask installed is told of a newer beta as of any update, and Update runs `brew update && brew upgrade --cask nushi@beta`. Without Homebrew (and on Linux), a beta installed from its [release's page](https://github.com/afrase/nushi/releases) is told of newer ones too, with Download. A beta keeps chats and settings readable by the latest release.

## Upgrading

Upgrading quits the app and opens the new one. The daemon keeps running, and its chats with it. It restarts into the new version by itself once nothing would be lost:

- no chat has a turn running or waiting on you;
- nothing is queued;
- no terminal runs a command.

Until then a notice under the header says "Nushi will update its daemon when the chats are idle", with what it waits for (each a link to its chat) and Restart now. Chats reopen where they were on their next message; terminals sitting at their prompt close.

Each release is a new program to macOS. After an upgrade, a Jira token (and a GitHub token you pasted) needs your OK once more: click Allow…, then Always Allow in macOS's prompt ([Jira](jira.md)). gh's own login isn't affected.

## Uninstalling

On Linux, `~/.local/opt/nushi/install.sh --uninstall` (above); the rest of this section is the Mac's.

Uninstalling quits the app. The daemon stops by itself within about a minute once the app is gone, also when you drag it to the Trash. Start at login's item goes with the app.

Chats' data stays in `~/Library/Application Support/Nushi`. **`--zap` deletes it**:

- Nushi's copies of every chat's transcript;
- settings, trust answers, remote access keys and paired devices;
- the adapters and the logs;
- the app's preferences.

It doesn't touch the agents' own history (`~/.claude`, `~/.codex`, `~/.ante`, `~/.omp`, `~/.local/share/opencode`, `~/.pi`, `~/.pig`): those chats still resume in a terminal. The keychain's "Nushi Jira" and "Nushi GitHub" items stay too. Remove the sites in Settings first, or delete them in Keychain Access.

## The daemon

Nushi, an agentic development environment (ADE), is two programs: a Go daemon, `nushid`, that runs the agents, and a Flutter app that is the window.

- The packaged app carries `nushid` in `Contents/Helpers/Nushi Daemon.app`, a background-only app (on Linux in `lib/nushid`). It starts it when no daemon is running, and leaves it running when it quits ([ADR 0013](adr/0013-app-starts-its-daemon.md), [ADR 0036](adr/0036-the-daemon-is-a-background-helper-app.md)).
- Settings › Start at login also starts it at login.
- A daemon whose app is deleted stops within about a minute. One whose app is replaced (an upgrade, `make install`) keeps running until it restarts.
- Settings › Logs & advanced shows the app's version and the running daemon's. `nushid -version` in the helper app says the same.

## Data and logs

The daemon keeps its socket, token and log in `~/Library/Application Support/Nushi/` (on Linux `~/.local/share/nushi/`, or `$XDG_DATA_HOME/nushi`):

- `nushid.log`, rotated at 10 MB, with two older copies;
- `app.log`, for what the app logged while the daemon didn't answer.

Settings › Logs & advanced reveals them, and turns on debug lines (or set `NUSHI_LOG=debug`). One chat's lines are `grep 'chat=<id>' nushid.log`. [ADR 0038](adr/0038-logs-you-can-debug-from.md) says what is logged and what never is.

Everything Nushi writes outside its data folder, and why, is in [What Nushi changes outside its data folder](user/outside-the-data-folder.md).
