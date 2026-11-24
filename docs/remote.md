# Remote access and the phone

A phone follows your chats through a relay you run. The daemon dials out to the relay, the phone connects to it, and everything between the two is end-to-end encrypted.

## Remote access

Settings › Remote access connects the daemon to a relay you name (`wss://…`), so a phone can reach it from anywhere.

- It's off until you turn it on.
- Nothing listens on the Mac: the daemon dials out, through the Mac's proxy settings (the daemon's environment's `HTTPS_PROXY`, as its login shell starts it, not what only an interactive shell sets, else the system's proxy or PAC file; not WPAD, NTLM or Kerberos).
- While it's on, the Mac doesn't idle-sleep (`caffeinate`). A closed lid on battery still sleeps.
- "Pair a phone" shows a QR code. The phone then shows a six-digit code, and the Mac asks to allow it, by name and code.
- Everything between the phone and the daemon is end-to-end encrypted with Noise, and a paired phone is a full client, like the app ([ADR 0034](adr/0034-noise-between-phone-and-daemon.md), with the threat model).
- Each paired device says whether it's the web app or an app and whether its notifications are on, with Send a test notification and Revoke.

## The phone

The phone is Nushi's web app, added to the Home Screen ([ADR 0054](adr/0054-the-phone-is-a-web-app-with-web-push.md)). It has:

- the chats with what each is doing: those that need you first, as a group at the top, then the pinned (Pin and Unpin in a chat's ⋯);
- a chat's transcript and composer: send, Queue and Stop and send while a turn runs, Stop;
- its prompts and questions, answered with a tap;
- a file the agent wrote, previewed full screen (its tool row's Preview, or Artifacts in the chat's bar). An HTML page or a Mermaid diagram shows in a sandboxed frame, a page without the files beside it; a PDF only on the Mac;
- New chat, and Settings.

Your relay serves it (`-origin`, below), so it comes from a server you run.

### Pairing an iPhone

On an iPhone with iOS 16.4 or later:

1. Open your relay's address in Safari (`https://<your relay>/`), tap Share › Add to Home Screen, and open Nushi from the Home Screen. Pair there, not in Safari: the Home Screen app keeps its own storage, and only it gets notifications.
2. On the Mac: Settings › Remote access › Pair a phone. In Nushi on the iPhone, name the device, tap Scan QR code (allow the camera) and point it at the Mac's code: pairing starts. Or Copy link on the Mac and paste it (Universal Clipboard) into Pairing link, then Pair. The iPhone's own Camera opens the code in Safari, which can only say to open Nushi and scan there.
3. Check that the iPhone's six-digit code is the one the Mac shows, and Allow on the Mac.
4. Turn on Settings › Notifications, and Allow when iOS asks.

A notification says only what happened ("Claude finished", "Claude's turn failed", "Codex needs you", "Claude has a question", and for a Claude workflow "Claude's workflow finished", "…failed" or "…stopped", once, as it ends); tapping it opens that chat. A workflow's end and the turn's end after it take one place, the newer replacing the older, as two turns' ends do. None comes for the chat you have open, nor for a turn that was stopped (by you, or by Nushi putting the agent to sleep or archiving the chat). A turn whose agent quit or crashed mid-turn counts as failed.

Forget this Mac (Settings) forgets the pairing and the device's key on the phone; revoke the device on the Mac too. The web app works the same way in a desktop browser, and Chrome on a Mac gets notifications too.

### Using it

- When the Mac can't be reached the app says so quietly ("Reconnecting…") and keeps trying. After a couple of tries it says why ("it's asleep or offline, or its remote access is off") and when it last answered, with Try again.
- A long chat opens with its latest part; older parts come as you scroll up, and the round ↓ at the bottom right takes you back to the latest (amber when the agent needs you).
- Scrolling a chat while you type keeps the keyboard up; a tap on the transcript puts it away.
- A chat's ⋯ shows its folder, branch and model, with Rename, Sleep, Archive and Stop for what runs in the background.
- An expired chat is read-only, with New chat here.
- After the first visit the app starts from its own cache. A new version shows "Nushi was updated", with Reload.
- A daemon below the app's API floor (ADR 0004; the phone's floor is the one built into the relay's web app, so it moves when the relay is updated) gets a bar, "Open Nushi on your Mac to update its daemon"; the phone keeps working, and a call the older daemon lacks fails with those words. Only the Mac's app updates the daemon.

### If a phone is lost or stolen

Revoke it on the Mac (Settings › Remote access). The daemon moves to a new id and key at the relay; phones connected then move at once, and the others when they next connect (a phone on a copy of the app from before 2026-11-04 moves once it takes the update: "Nushi was updated", Reload). A paired phone can read any file on the Mac, the daemon's key too, and with it could still answer as the Mac to a phone that hasn't moved yet. So if it may have been used before you revoked it, pair your other phones again (Forget this Mac on each, then pair), and look on the Mac for anything it left (a device paired since, a LaunchAgent, a changed shell profile): it could run anything as you.

### If the app's code may have been changed

Whoever serves the web app (the relay's host, a proxy that terminates TLS such as Cloudflare) can serve code that takes the device's key. If that may have happened:

1. Reinstall `nushi-relay` by hand from the release's tarball, checked against its `.sha256` from the release (the manual steps in [Updating a relay from a release](#updating-a-relay-from-a-release)), and restart it. Not with `nushi-relay -update`: a binary that may have been changed can't be trusted to replace itself; the app is inside the binary, so that puts it back. A relay still run with `-web <folder>` serves that folder instead: take `-web` out of its service (keep `-origin`) and delete the folder.
2. Purge the proxy's cache (Cloudflare keeps the app's hashed files at its edge for a year).
3. Cut a new release if the files themselves were wrong.
4. Revoke every phone on the Mac.
5. On each phone, delete Nushi from the Home Screen, which deletes its storage (in a desktop browser, clear the site's data), then add it again and pair again. Don't rely on Forget this Mac: if altered code is what runs, the button is its code too.

The app's service worker checks every file it serves from its cache against the build's SHA-256s, so something kept once can't outlive the server being put right; it can't tell, though, whether the server is right.

## The relay

A phone reaches the daemon through a relay: `nushi-relay`, one static binary that pairs two WebSocket connections on an id and copies their messages. Only the daemon, holding its key, can listen on an id, and the messages are end-to-end encrypted between the phone and the daemon.

It keeps nothing: no accounts, no disk, no logs beyond starting ([ADR 0033](adr/0033-the-relay-is-a-dumb-pipe.md) says what it can still see). Anyone can run one; Nushi doesn't run one for you.

### Building and running it

```sh
make relay                                   # bin/nushi-relay, no cgo
bin/nushi-relay -addr 127.0.0.1:8080         # plain ws://, e.g. behind a reverse proxy
bin/nushi-relay -host relay.example.com      # wss:// on :443 with a Let's Encrypt certificate
bin/nushi-relay -h                           # the caps: message size, rate, idle time, connections
make relay-web                               # the same with the phone's web app built in, as a release's
bin/nushi-relay -addr 127.0.0.1:8090 -origin https://relay.example.com
```

- **A release's relay has the phone's web app built in** ([ADR 0113](adr/0113-the-relay-has-the-web-app-built-in.md)): one file to copy, or to put in a container. `make relay` builds one without it.
- **`-origin`** serves the app at that address, the one the browser sees (scheme, host and port), and takes WebSockets from pages there only. Without it the relay only copies messages.
- **`-web <folder>`** serves the app from a folder instead (`make web` builds it into `app/build/web`), for trying a build. With `-host`, its origin is `https://<host>` unless given.
- **Behind any HTTPS reverse proxy**, `-origin` is the proxy's public address and `-ip-header` its header with the client's address (below).
- **Use `wss://`.** Company proxies tunnel 443 but often break a plain `ws://` upgrade, and iOS refuses plain connections by default.

### Behind a Cloudflare tunnel

The author's relay runs on a Raspberry Pi behind a Cloudflare named tunnel (`cloudflared`, which terminates TLS):

```sh
nushi-relay -addr 127.0.0.1:8090 -ip-header CF-Connecting-IP \
  -origin https://nushi.example.com -plain-per-ip 32
```

The Mac's relay is then `wss://nushi.example.com`.

- Cloudflare drops a WebSocket that's silent for about 100 s; both ends ping well within that.
- Whoever terminates TLS can serve the app's code (ADR 0054): a CDN in front is trusted for it, as the relay's host is.
- A web app loads a few dozen files at once, hence the higher cap on plain connections per address (`-plain-per-ip`). One IPv6 /48 (an IPv4 address is its own) holds 64 at most (`-plain-per-net`), never fewer than `-plain-per-ip`.
- Tailscale Funnel worked too, but slowly: about 0.1–0.3 MB/s, and seconds per connection.

### On a VPS

On any small Linux box: install a release's relay once by hand, with the manual steps in [Updating a relay from a release](#updating-a-relay-from-a-release) (or build one with the app inside, `GOOS=linux GOARCH=amd64 make relay-web`, and copy it there), point a DNS name at the box, and run it as a service with port 443 open:

```ini
# /etc/systemd/system/nushi-relay.service
[Service]
ExecStart=/usr/local/bin/nushi-relay -host relay.example.com -origin https://relay.example.com -cert-cache /var/lib/nushi-relay
AmbientCapabilities=CAP_NET_BIND_SERVICE
DynamicUser=yes
StateDirectory=nushi-relay
Restart=always
[Install]
WantedBy=multi-user.target
```

The certificate cache is the only thing it writes. Without `-cert-cache`, each start asks Let's Encrypt for a new certificate, and frequent restarts run into its rate limits. Later releases: `sudo nushi-relay -update -restart-unit nushi-relay` ([Updating a relay from a release](#updating-a-relay-from-a-release)).

### On Fly.io

The image takes a release's relay, which has the phone's app inside; one built from source with `go build` has none, and refuses to start with `-origin`. In an empty folder, download `nushi-relay-X.Y.Z-linux-amd64.tar.gz` and its `.sha256` from [Releases](https://github.com/afrase/nushi/releases), check and unpack it (`sha256sum -c nushi-relay-X.Y.Z-linux-amd64.tar.gz.sha256 && tar -xzf nushi-relay-X.Y.Z-linux-amd64.tar.gz`), add these two files, then run `fly launch --no-deploy` and `fly deploy`, with Fly terminating TLS:

```dockerfile
FROM scratch
COPY nushi-relay /nushi-relay
# -origin: the app's own address. 172.16.0.0/12: where Fly's proxy has been seen connecting from (below).
CMD ["/nushi-relay", "-addr", ":8080", "-origin", "https://my-nushi-relay.fly.dev", "-ip-header", "Fly-Client-IP", "-trusted-proxy", "172.16.0.0/12", "-plain-per-ip", "32"]
```

```toml
# fly.toml
app = "my-nushi-relay"
[[services]]
  internal_port = 8080
  protocol = "tcp"
  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]
```

- Fly's edge then sees what the relay sees (ids, timing, sizes, addresses), and may log requests; terminating TLS, it can also serve the app's code, as the relay's host can (ADR 0054).
- `-plain-per-ip 32`: the app loads a few dozen files at once, as behind Cloudflare. To update, unpack a newer release's relay there and `fly deploy` again.
- Fly's proxy doesn't reach the relay over loopback, so the relay believes `Fly-Client-IP` only from the `-trusted-proxy` range. Fly doesn't document the proxy's address; its community reports 172.16.x.x, hence 172.16.0.0/12 above. Check it on your machine before relying on it (`ss -tn` in a debug image of the app while a phone connects). A range that misses the proxy counts every client under the proxy's one address (one per-address cap and rate for all, and one `-listen-per-ip` cap of listeners for every daemon behind it); one too wide lets anything in it that reaches port 8080 name its own address (your organization's other machines come over its private IPv6 network, outside this range).
- For TLS of the relay's own, give the port no handlers, run `-host` with `-cert-cache` on a volume, and copy `/etc/ssl/certs/ca-certificates.crt` into the image (autocert talks to Let's Encrypt over HTTPS).

### The client's address

`-ip-header` makes the per-address caps count the client's address rather than its proxy's (Fly's `Fly-Client-IP`, Cloudflare's `CF-Connecting-IP`).

- Behind a proxy of your own, name a header it sets (nginx's `X-Real-IP $remote_addr`), or one it appends to (`X-Forwarded-For` with `$proxy_add_x_forwarded_for`, HAProxy's `option forwardfor`).
- With an appended header, the relay takes the last entry, the one the proxy added, since the client writes what comes before. With several proxies in a row, `-ip-hops` says how many append.
- Never name a header the proxy passes on as the client sent it.
- The header is believed only from a loopback peer (a proxy on the same machine, as cloudflared or Caddy usually is) when `-trusted-proxy` isn't given, or only from the addresses it names (comma-separated addresses or CIDRs) when it is: naming any replaces loopback, so with a proxy on the same machine as well, name `127.0.0.1,::1` too. Any other peer is counted under its own address. Still bind the relay where only the proxy reaches it (`-addr 127.0.0.1:8090`).

### Updating a relay from a release

Each release has `nushi-relay-X.Y.Z-linux-arm64.tar.gz` (and `linux-amd64`): one static binary with that release's web app built in ([ADR 0113](adr/0113-the-relay-has-the-web-app-built-in.md)). Update it along with the Mac, with one command on the relay's machine ([ADR 0149](adr/0149-the-relay-updates-itself-when-asked.md)):

```sh
sudo nushi-relay -update -restart-unit nushi-relay
```

- It asks GitHub for the latest stable release of `afrase/nushi` and, if it is newer, downloads this machine's tarball and its `.sha256`, checks one against the other, runs the new binary once with `-version`, puts it in place of the one you ran (its mode and owner kept) and restarts the service. The same version or an older one: it says so and does nothing.
- Without `-restart-unit` it installs and tells you to restart the service yourself. It exits 1 on any failure, with the installed relay untouched.
- It needs root because the binary is root's (`/usr/local/bin`); run without it, it says so before downloading anything.
- A relay you built yourself (`make relay-web`) has no release's version and refuses: it has nothing to compare.
- What it trusts: GitHub's answer for `afrase/nushi`, over TLS. The `.sha256` comes from the same release, so it checks the download, not who made it: releases aren't signed. Whoever can publish a release there can change every relay that runs this command, and the relay serves the phone's app, which holds the phone's key ([ADR 0054](adr/0054-the-phone-is-a-web-app-with-web-push.md)).

**A timer, if you want it.** The relay never updates by itself. To have it check weekly, add these two units and run `sudo systemctl enable --now nushi-relay-update.timer`. Only do it if you accept the sentence above for every release, unattended: a release published to `afrase/nushi` then reaches your relay, and your phone, within a week, with no one looking.

```ini
# /etc/systemd/system/nushi-relay-update.service
[Unit]
Description=Update nushi-relay to the latest release
[Service]
Type=oneshot
ExecStart=/usr/local/bin/nushi-relay -update -restart-unit nushi-relay
```

```ini
# /etc/systemd/system/nushi-relay-update.timer
[Timer]
OnCalendar=weekly
RandomizedDelaySec=1h
Persistent=true
[Install]
WantedBy=timers.target
```

`journalctl -u nushi-relay-update` shows what each run did.

**By hand**, for a first install, a relay from before the command (it answers `flag provided but not defined: -update`), or when the command can't run:

```sh
sha256sum -c nushi-relay-X.Y.Z-linux-arm64.tar.gz.sha256   # its .sha256, from the same release
tar -xzf nushi-relay-X.Y.Z-linux-arm64.tar.gz && sudo install nushi-relay /usr/local/bin/
nushi-relay -version                   # then restart its service
```

A relay set up before 0.30.0 served the app from a folder: take `-web <folder>` out of its service (keep `-origin`) and delete the folder.
