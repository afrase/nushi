# 0036. The daemon is a background-only helper app, opened through Launch Services; Start at login through a launch agent

Supersedes how [0013](0013-app-starts-its-daemon.md) starts the daemon and its "No launchd agent"; the rest of 0013 holds.

## Context
The app started `Contents/MacOS/nushid` itself, detached, through the login shell. A process the app spawns stays in the app's resource coalition, detached or not (`setsid` doesn't leave it), so after a quit Launch Services kept the app as "exited-with-subordinates" and the Dock showed "Nushi Running in Background" with a generic icon. Only launchd puts a process in a coalition of its own: an app Launch Services opens, or a launchd job. The owner also wants the daemon up after a reboot, without opening the app, so chats and the phone relay are reachable.

## Decision
- `nushid` lives in `Contents/Helpers/Nushi Daemon.app` (`com.nushihq.Nushi.daemon`, `LSBackgroundOnly`, the app's icon); the executable keeps its name, so `make stop` and "Restart daemon" find it. "Nushi Daemon" because it is the daemon: Activity Monitor shows that name, and the app's own words are "Restart daemon" and `nushid.log`; "Helper" says less.
- The app starts it with `open -n -g <helper> --args -login` (plus `--env NUSHI_DATA=…` when the app has one). `-n` so a second data folder's daemon can run beside the first. `nushid -login` replaces itself with the user's login shell (from the user database), which replaces itself with `nushid`: the pid, and so the helper app, stay, and the daemon gets the terminal's environment ([0028](0028-agents-get-the-login-shells-environment.md)).
- Start at login is a setting, off by default, only in the packaged app and for the usual data folder. On registers `Contents/Library/LaunchAgents/com.nushihq.Nushi.daemon.plist` with `SMAppService` (macOS 13 and later); its program is `Contents/Resources/start-daemon`, a script that opens the helper the same way and exits. So every daemon is the helper app, whoever started it.
- The program is a script, not `nushid`: launchd pins an ad-hoc signed Mach-O program to its cdhash, and after a rebuild launching it fails ("Launch Constraint Violation"); neither registering again nor launchd's repair (BTM: "Invalid argument") lifts it without a Team ID. A script gets no such constraint (tried: a rebuilt helper and a changed script both launched).
- No `KeepAlive`: launchd only ever runs the script, which ends at once; the daemon is never launchd's job. Restart on crash would need launchd to own `nushid`, which the cdhash pin rules out under ad-hoc signing, and it would hold only for the daemon launchd started. So "Restart daemon", `make stop` and the outdated-daemon screen work as before, and the app still starts a daemon when none answers.

## Consequences
- Quitting the app leaves no Dock entry. Activity Monitor lists "Nushi Daemon" with the Nushi icon.
- A daemon started from the old place (`Contents/MacOS/nushid`) runs until it is restarted; "Restart daemon" brings up the helper. The data folder doesn't change.
- Turning Start at login on also starts the script once (`RunAtLoad`): with a daemon running, the new one finds it and stops, one line in `nushid.log`. Off unregisters the job; a running daemon keeps running.
- A daemon that crashes while the app is closed stays down until the app opens or the next login.
- macOS shows "Nushi can run in the background" when it's turned on, and the item under Login Items › Allow in the Background, where it can be switched off; the app then shows the setting off or waiting for approval.

## Alternatives considered
- `KeepAlive` on a job running `nushid`: crash restarts, but broken by every rebuild under ad-hoc signing (above), and it would fight `make stop` unless the daemon told stops from crashes.
- A transient job (`launchctl bootstrap`/`submit` of a plist written at run time): files outside the bundle, and `submit` keeps the job alive.
- Disclaiming responsibility at spawn (`posix_spawnattr`): private API, and the process would still be in the app's coalition.
- `LSUIElement`: allows windows and a menu bar; the daemon has neither.
