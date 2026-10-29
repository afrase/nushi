# 0056. An older daemon restarts itself into the bundled one once nothing runs

Status: accepted, 2026-10-28. Amends [0004](0004-connect-over-unix-socket.md) (the blocking screen), [0013](0013-app-starts-its-daemon.md) (the app never restarts a daemon by itself) and [0055](0055-releases-and-the-homebrew-cask.md) (upgrades offer Restart daemon).

## Context
An upgrade (Homebrew's, or `make install`) leaves the running daemon and its chats alone (0055), and the app then asked the owner to click "Restart daemon" after every one: "Why is a daemon reset always required?" A restart stops agents mid-turn and ends terminals, so doing it blindly loses work; doing it when nothing runs loses nothing that a sleep wouldn't (chats reopen through `session/load` on their next message).

## Decision
- **The app asks; the daemon waits.** While the app bundles a newer daemon than the one running (by API version, or the same API and a later program time, so an older copy of the app open at once never takes the daemon back), and the daemon knows how (API 77), each ping (every 2 s) also calls `RestartWhenIdle`. An ask lapses after 15 s unless repeated, so a daemon whose app quit keeps running: only the app starts the new one. Mac-only, never a device's channel.
- **Idle** is what sleep needs, across every chat (side chats too) but without the idle time: no turn running or reopening, nothing waiting on a permission or a question, nothing queued (the queue lives only in the daemon), no background command or subagent running, no throwaway fork. A chat open between turns is idle. And no terminal runs a command (a program other than its shell in the foreground): terminals end with the daemon, so it waits for them rather than kill a build or a server; one at its prompt loses only its scrollback.
- **No gap between the check and the exit.** `chats.Rest` checks every chat, sets a flag that makes `Prompt` refuse (checked under the chat's lock, which a prompt holds until its turn has started or it's queued), and checks again; anything that started meanwhile clears the flag and the wait goes on. Checked every second. A refused prompt is `Unavailable` ("restarting"): the app's `sendPrompt` waits for the new daemon's build (a minute at most) and sends it again, so a message sent in that moment goes to the new daemon rather than being held in a queue that would die with the old one.
- **Order of the stop.** The chats' agents and the terminals close first, while the socket still answers (prompts refused); then the socket closes. The app starts the bundled daemon only when a ping fails, so the two never run at once.
- **While it waits the app works as usual**, even when the daemon is behind on the API: what runs must stay visible and answerable, or a permission card would hold the restart forever. Calls the older daemon lacks fail as errors for those minutes. A bar says "Nushi will update its daemon when the chats are idle." with Restart now (which asks first when it would stop something); while the daemon is gone, "Starting the new daemon…". A daemon older than API 77 keeps the blocking screen and its Restart daemon button.
- The phone does nothing: its channel drops with the old daemon, and the next call dials the relay again and reaches the new one.

## Consequences
- After an upgrade the daemon restarts within about a second of the last turn ending (the app starts the new one within about 2 s more); the owner clicks nothing.
- A chat that stays busy or waits on an answer for hours holds the restart that long; Restart now is the way out.
- A held queue (after a stopped turn) holds it too, until it is sent or emptied.

## Alternatives considered
- Holding a prompt that comes in the moment of the restart in the queue: the queue isn't stored, so it would have to be, for one rare case.
- The daemon starting its successor itself: an app-less restart, but two launchers (the app also starts one when none answers) race for the socket.
- Restarting with terminals running commands: kills builds and servers the owner started.
