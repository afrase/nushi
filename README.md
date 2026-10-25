<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/brand/mark-dark.svg"><img src="docs/brand/mark.svg" width="88" alt=""></picture></p>

# Nushi

A macOS app for running coding agents as chats over the [Agent Client Protocol](https://agentclientprotocol.com), plus a diff viewer. A Go daemon (`nushid`) runs the agents; a Flutter app is the window.

## Requirements

- Go (current stable) and Flutter on `PATH`
- For `make gen`: `dart pub global activate protoc_plugin` and `dart pub global activate connectrpc` (buf runs through `go run`)

## Run

```sh
make run     # starts nushid in the background (if it isn't running), then the app
make stop    # stops nushid
make test    # all tests
make gen     # regenerate the API code after editing proto/
make lines   # hand-written line counts
make package # a release "Nushi.app" with nushid inside (ad-hoc signed)
make install # package, then copy it to ~/Applications
make icons   # redraw the app icon and the mark (tools/icongen)
```

The packaged app starts its bundled `nushid` when no daemon is running, and leaves it running when it quits ([ADR 0013](docs/adr/0013-app-starts-its-daemon.md)). With `make run`, start and stop the daemon yourself.

The daemon keeps its socket, token and log in `~/Library/Application Support/Nushi/`. To try a build beside a Nushi that's in use, give both another folder: `NUSHI_DATA=~/Library/Application\ Support/Nushi\ Dev make run` (and the same for `make stop`).

## Agents

"New chat" (⌘N, or a folder's +) asks which agent to run, with the one used last picked: Enter starts it. A chat keeps its agent, and shows its mark in the sidebar.

- **Claude**, through `npx --yes @agentclientprotocol/claude-agent-acp@0.94.0`. It uses Claude Code's own login and settings.
- **Codex**, through `npx --yes @agentclientprotocol/codex-acp@2.2.2`, which brings Codex 0.160.1. It uses Codex's own login or config (`$CODEX_HOME`, else `~/.codex`): sign in with `codex login`, or name a provider in `config.toml` (NOTES.md has one for Fireworks). A provider's key comes from the environment, which agents get from your login shell when the app starts the daemon ([ADR 0028](docs/adr/0028-agents-get-the-login-shells-environment.md)). A Codex chat resumes in a terminal with `codex resume <session id>`.

- **Ante**, through Nushi's own bridge (`nushid ante-acp`, [ADR 0030](docs/adr/0030-our-own-bridge-for-ante.md)), which runs an `ante serve --stdio` per session. It needs Ante 0.2.14 or newer (`ante` on `PATH`, or in `~/.ante/bin`) and uses Ante's own settings, providers and sign-in (`~/.ante`, or `$ANTE_HOME`). An Ante chat resumes in a terminal with `ante --resume <session id>`.
- **oh-my-pi**, through `npx --yes -p bun@1.4.3 -p @oh-my-pi/pi-coding-agent@18.12.6 omp --mode acp` (omp needs Bun, which npx brings beside it). It uses omp's own config and keys (`~/.omp`, the environment: `FIREWORKS_API_KEY` for Fireworks). An omp chat resumes in a terminal with `omp --resume <session id>`; Nushi can't delete an omp session's history.

Claude, Codex and oh-my-pi need `npx` (Node) on the login shell's `PATH`; npx installs the pinned package and says where its program is, and the daemon runs that program itself (npx doesn't stay running). What each agent can do (fork, rewind, steering, questions, the context breakdown, MCP) follows what it reports; a control it lacks isn't shown.

A chat whose agent isn't needed can sleep: its agent stops and the chat stays, and the next message wakes it (`session/load`). Chats sleep on their own after 30 idle minutes when nothing would be lost (Settings changes the time), or from a chat's menu ([ADR 0032](docs/adr/0032-idle-chats-sleep.md)). The bar along the window's bottom counts working, awake and sleeping agents, and shows the memory Nushi takes; a click lists each awake chat's.

## Remote access

Settings → Remote access connects the daemon to a relay you name (`wss://…`), so a phone can reach it from anywhere; it's off until you turn it on, and nothing listens on the Mac: the daemon dials out, through the Mac's proxy settings (the environment's `HTTPS_PROXY`, else the system's proxy or PAC file; not WPAD, NTLM or Kerberos). While it's on, the Mac doesn't idle-sleep (`caffeinate`); a closed lid on battery still sleeps. "Pair a phone" shows a QR code; the phone then shows a six-digit code, and the Mac asks to allow it by name and code. Everything between the phone and the daemon is end-to-end encrypted with Noise, and a paired phone is a full client, like the app ([ADR 0034](docs/adr/0034-noise-between-phone-and-daemon.md), with the threat model). The phone app itself isn't built yet; `packages/remote_transport` is its side of the channel.

## The relay

A phone reaches the daemon through a relay: `nushi-relay`, one static binary that pairs two WebSocket connections on an id (only the daemon, holding its key, can listen there) and copies their messages, which are end-to-end encrypted between the phone and the daemon. It keeps nothing: no accounts, no disk, no logs beyond starting ([ADR 0033](docs/adr/0033-the-relay-is-a-dumb-pipe.md) says what it can still see). Anyone can run one; Nushi doesn't run one for you.

```sh
make relay                                   # bin/nushi-relay, no cgo
bin/nushi-relay -addr 127.0.0.1:8080         # plain ws://, e.g. behind a reverse proxy
bin/nushi-relay -host relay.example.com      # wss:// on :443 with a Let's Encrypt certificate
bin/nushi-relay -h                           # the caps: message size, rate, idle time, connections
```

Use `wss://`: company proxies tunnel 443 but often break a plain `ws://` upgrade, and iOS refuses plain connections by default.

**On a VPS** (any small Linux box): build with `GOOS=linux GOARCH=amd64 make relay`, copy the binary, point a DNS name at the box, and run it as a service with port 443 open:

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

The certificate cache is the only thing it writes; without `-cert-cache` each start asks Let's Encrypt for a new certificate, and frequent restarts run into its rate limits.

**On Fly.io** (`fly launch --no-deploy`, then `fly deploy`), with Fly terminating TLS:

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

`-ip-header` makes the per-address caps count Fly's client address rather than its proxy's. Behind a proxy of your own, name a header it sets (nginx's `X-Real-IP $remote_addr`) or one it appends to (`X-Forwarded-For` with `$proxy_add_x_forwarded_for`, HAProxy's `option forwardfor`): the relay takes the last entry, the one the proxy added, since the client writes what comes before; with several proxies in a row, `-ip-hops` says how many append. Never a header the proxy passes on as the client sent it. Fly's edge then sees what the relay sees (ids, timing, sizes, addresses), and may log requests. For TLS of the relay's own, give the port no handlers, run `-host` with `-cert-cache` on a volume, and copy `/etc/ssl/certs/ca-certificates.crt` into the image (autocert talks to Let's Encrypt over HTTPS).

Decisions are in [`docs/adr/`](docs/adr/README.md).
