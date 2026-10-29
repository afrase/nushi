# Remote access and the phone

A phone follows your chats through a relay you run. The daemon dials out to the relay, the phone connects to it, and everything between the two is end-to-end encrypted.

## Remote access

Settings › Remote access connects the daemon to a relay you name (`wss://…`), so a phone can reach it from anywhere.

- It's off until you turn it on.
- Nothing listens on the Mac: the daemon dials out, through the Mac's proxy settings (the environment's `HTTPS_PROXY`, else the system's proxy or PAC file; not WPAD, NTLM or Kerberos).
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

Your relay serves it (`-web`, below), so it comes from a server you run.

### Pairing an iPhone

On an iPhone with iOS 16.4 or later:

1. Open your relay's address in Safari (`https://<your relay>/`), tap Share › Add to Home Screen, and open Nushi from the Home Screen. Pair there, not in Safari: the Home Screen app keeps its own storage, and only it gets notifications.
2. On the Mac: Settings › Remote access › Pair a phone. In Nushi on the iPhone, name the device, tap Scan QR code (allow the camera) and point it at the Mac's code: pairing starts. Or Copy link on the Mac and paste it (Universal Clipboard) into Pairing link, then Pair. The iPhone's own Camera opens the code in Safari, which can only say to open Nushi and scan there.
3. Check that the iPhone's six-digit code is the one the Mac shows, and Allow on the Mac.
4. Turn on Settings › Notifications, and Allow when iOS asks.

A notification says only what happened ("Claude finished", "Codex needs you", "Claude has a question"); tapping it opens that chat. None comes for the chat you have open.

Forget this Mac (Settings) forgets the pairing and the device's key on the phone; revoke the device on the Mac too. The web app works the same way in a desktop browser, and Chrome on a Mac gets notifications too.

### Using it

- When the Mac can't be reached the app says so quietly ("Reconnecting…") and keeps trying. After a couple of tries it says why ("it's asleep or offline, or its remote access is off") and when it last answered, with Try again.
- A long chat opens with its latest part; older parts come as you scroll up.
- A chat's ⋯ shows its folder, branch and model, with Rename, Sleep, Archive and Stop for what runs in the background.
- An expired chat is read-only, with New chat here.
- After the first visit the app starts from its own cache. A new version shows "Nushi was updated", with Reload.

## The relay

A phone reaches the daemon through a relay: `nushi-relay`, one static binary that pairs two WebSocket connections on an id and copies their messages. Only the daemon, holding its key, can listen on an id, and the messages are end-to-end encrypted between the phone and the daemon.

It keeps nothing: no accounts, no disk, no logs beyond starting ([ADR 0033](adr/0033-the-relay-is-a-dumb-pipe.md) says what it can still see). Anyone can run one; Nushi doesn't run one for you.

### Building and running it

```sh
make relay                                   # bin/nushi-relay, no cgo
bin/nushi-relay -addr 127.0.0.1:8080         # plain ws://, e.g. behind a reverse proxy
bin/nushi-relay -host relay.example.com      # wss:// on :443 with a Let's Encrypt certificate
bin/nushi-relay -h                           # the caps: message size, rate, idle time, connections
make web                                     # the phone's web app, into app/build/web
bin/nushi-relay -addr 127.0.0.1:8090 -web app/build/web -origin https://relay.example.com
```

- **`-web`** serves the phone's web app at `-origin`, and takes WebSockets from pages there only. Copy `app/build/web` to the relay's machine. `make web` writes a Brotli copy beside each file, which the relay serves to browsers that take it.
- **`-origin`** is the address the browser sees: scheme, host and port. With `-host`, it's `https://<host>` unless given.
- **Behind any HTTPS reverse proxy**, `-origin` is the proxy's public address and `-ip-header` its header with the client's address (below).
- **Use `wss://`.** Company proxies tunnel 443 but often break a plain `ws://` upgrade, and iOS refuses plain connections by default.

### Behind a Cloudflare tunnel

The author's relay runs on a Raspberry Pi behind a Cloudflare named tunnel (`cloudflared`, which terminates TLS):

```sh
nushi-relay -addr 127.0.0.1:8090 -ip-header CF-Connecting-IP \
  -web /usr/local/share/nushi-web -origin https://nushi.example.com -plain-per-ip 32
```

The Mac's relay is then `wss://nushi.example.com`.

- Cloudflare drops a WebSocket that's silent for about 100 s; both ends ping well within that.
- Whoever terminates TLS can serve the app's code (ADR 0054): a CDN in front is trusted for it, as the relay's host is.
- A web app loads a few dozen files at once, hence the higher cap on plain connections per address (`-plain-per-ip`).
- Tailscale Funnel worked too, but slowly: about 0.1–0.3 MB/s, and seconds per connection.

### On a VPS

On any small Linux box: build with `GOOS=linux GOARCH=amd64 make relay`, copy the binary, point a DNS name at the box, and run it as a service with port 443 open:

```ini
# /etc/systemd/system/nushi-relay.service
[Service]
ExecStart=/usr/local/bin/nushi-relay -host relay.example.com -cert-cache /var/lib/nushi-relay
AmbientCapabilities=CAP_NET_BIND_SERVICE
DynamicUser=yes
StateDirectory=nushi-relay
Restart=always
[Install]
WantedBy=multi-user.target
```

The certificate cache is the only thing it writes. Without `-cert-cache`, each start asks Let's Encrypt for a new certificate, and frequent restarts run into its rate limits.

### On Fly.io

Run `fly launch --no-deploy`, then `fly deploy`, with Fly terminating TLS:

```dockerfile
FROM golang:1.27 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /nushi-relay ./cmd/nushi-relay
FROM scratch
COPY --from=build /nushi-relay /nushi-relay
CMD ["/nushi-relay", "-addr", ":8080", "-ip-header", "Fly-Client-IP"]
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

- Fly's edge then sees what the relay sees (ids, timing, sizes, addresses), and may log requests.
- For TLS of the relay's own, give the port no handlers, run `-host` with `-cert-cache` on a volume, and copy `/etc/ssl/certs/ca-certificates.crt` into the image (autocert talks to Let's Encrypt over HTTPS).

### The client's address

`-ip-header` makes the per-address caps count the client's address rather than its proxy's (Fly's `Fly-Client-IP`, Cloudflare's `CF-Connecting-IP`).

- Behind a proxy of your own, name a header it sets (nginx's `X-Real-IP $remote_addr`), or one it appends to (`X-Forwarded-For` with `$proxy_add_x_forwarded_for`, HAProxy's `option forwardfor`).
- With an appended header, the relay takes the last entry, the one the proxy added, since the client writes what comes before. With several proxies in a row, `-ip-hops` says how many append.
- Never name a header the proxy passes on as the client sent it.

### Updating a relay from a release

Each release has `nushi-relay-X.Y.Z-linux-arm64.tar.gz` (and `linux-amd64`, `darwin-arm64`: static binaries) and `nushi-web-X.Y.Z.tar.gz`. Update the web app along with the Mac:

```sh
tar -xzf nushi-relay-X.Y.Z-linux-arm64.tar.gz && sudo install nushi-relay /usr/local/bin/
sudo rm -rf /usr/local/share/nushi-web && sudo tar -xzf nushi-web-X.Y.Z.tar.gz -C /usr/local/share
nushi-relay -version                   # then restart its service
```
