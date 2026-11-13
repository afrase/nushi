// Command nushi-relay is the relay a Nushi daemon and its phones meet
// through. It copies end-to-end encrypted messages between two connections
// that name the same random id, and keeps nothing: no accounts, no disk,
// no logs beyond starting and fatal errors.
package main

import (
	"cmp"
	"context"
	"flag"
	"fmt"
	"log"
	"net"
	"net/netip"
	"strings"

	"golang.org/x/crypto/acme/autocert"

	"github.com/afrase/nushi/relay"
)

// version is the release the relay was built as (-ldflags -X
// main.version=X.Y.Z, as tools/release.sh does).
var version = "dev"

func main() {
	showVersion := flag.Bool("version", false, "print the relay's version and exit")
	addr := flag.String("addr", "", "address to listen on (default :8080, or :443 with -host)")
	host := flag.String("host", "", "serve TLS for this host name, with a Let's Encrypt certificate")
	cache := flag.String("cert-cache", "", "folder to keep the certificate in (default: memory only, so each start asks for a new one)")
	email := flag.String("email", "", "contact address for Let's Encrypt (optional)")
	lim := relay.Defaults
	flag.IntVar(&lim.MaxMessage, "max-message", lim.MaxMessage, "bytes in one message")
	flag.IntVar(&lim.Rate, "rate", lim.Rate, "bytes a second a connection may send")
	flag.IntVar(&lim.Burst, "burst", lim.Burst, "bytes a connection may send at once")
	flag.DurationVar(&lim.Idle, "idle", lim.Idle, "close a connection silent this long")
	flag.DurationVar(&lim.DialWait, "dial-wait", lim.DialWait, "how long a dialer waits for a listener")
	flag.DurationVar(&lim.MaxWait, "max-wait", lim.MaxWait, "how long a listener may wait for a dialer")
	flag.IntVar(&lim.PerID, "per-id", lim.PerID, "connections on one id")
	flag.IntVar(&lim.PerIP, "per-ip", lim.PerIP, "connections from one address (an IPv6 /64), at most half of -total")
	flag.IntVar(&lim.ListenPerIP, "listen-per-ip", lim.ListenPerIP, "listeners (daemons' waiting connections) from one address (an IPv6 /48); 0 for no cap")
	flag.Float64Var(&lim.NewRate, "new-rate", lim.NewRate, "new connections a second from one address")
	flag.Float64Var(&lim.NewBurst, "new-burst", lim.NewBurst, "new connections from one address at once")
	flag.StringVar(&lim.IPHeader, "ip-header", "", "behind a reverse proxy: the header holding the client's address (e.g. CF-Connecting-IP for cloudflared, Fly-Client-IP); of a list (X-Forwarded-For), the last entry")
	flag.IntVar(&lim.IPHops, "ip-hops", 1, "with -ip-header: how many proxies append to it (the client's address is this many from the right)")
	proxies := flag.String("trusted-proxy", "", "with -ip-header: the proxies whose header is believed, as comma-separated addresses or CIDRs (default: loopback only); any other peer counts under its own address")
	flag.IntVar(&lim.Total, "total", lim.Total, "connections in all")
	flag.DurationVar(&lim.HTTPIdle, "http-idle", lim.HTTPIdle, "close a plain HTTP connection (not a WebSocket) idle this long")
	flag.DurationVar(&lim.FirstWait, "first-wait", lim.FirstWait, "how long a new connection has for its first request's headers")
	flag.IntVar(&lim.PlainPerIP, "plain-per-ip", lim.PlainPerIP, "plain HTTP connections (not WebSockets) from one address")
	web := flag.String("web", "", "serve the web app in this folder instead of the one built into a release's relay (ADR 0113); needs -origin")
	origin := flag.String("origin", "", "serve the phone's web app (ADR 0054) at this origin, the one the browser sees it at (https://host[:port]) and the only one whose pages may connect; with -web and -host, https://<host> by default. Behind a reverse proxy (Tailscale Funnel, cloudflared, Caddy) it is the proxy's public address")
	flag.Parse()
	if *showVersion {
		fmt.Println("nushi-relay", version) //nolint:forbidigo // -version's answer
		return
	}

	trusted, err := trustedProxies(*proxies)
	if err != nil {
		log.Fatalf("-trusted-proxy: %v", err)
	}
	lim.TrustedProxies = trusted

	app, err := site(*web, *origin, *host, builtIn())
	if err != nil {
		log.Fatalf("-web and -origin: %v", err)
	}
	lim.Site = app
	srv := relay.NewServer(lim)
	if *host == "" {
		ln, err := new(net.ListenConfig).Listen(context.Background(), "tcp", cmp.Or(*addr, ":8080"))
		if err != nil {
			log.Fatal(err)
		}
		log.Printf("nushi-relay listening on %s", ln.Addr())
		log.Fatal(srv.Serve(ln))
	}
	m := &autocert.Manager{Prompt: autocert.AcceptTOS, HostPolicy: autocert.HostWhitelist(*host), Email: *email}
	if *cache != "" {
		m.Cache = autocert.DirCache(*cache)
	}
	srv.TLSConfig = m.TLSConfig()
	ln, err := new(net.ListenConfig).Listen(context.Background(), "tcp", cmp.Or(*addr, ":443"))
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("nushi-relay listening on %s, TLS for %s", ln.Addr(), *host)
	log.Fatal(srv.ServeTLS(ln, "", ""))
}

// trustedProxies parses -trusted-proxy: comma-separated addresses (each a
// prefix of its full length) and CIDRs, masked. A mistake is an error, not
// a skipped entry: per-address caps would otherwise believe a header from
// a peer the operator didn't name, or not from one they did.
func trustedProxies(list string) ([]netip.Prefix, error) {
	var out []netip.Prefix
	for p := range strings.SplitSeq(list, ",") {
		if p = strings.TrimSpace(p); p == "" {
			continue
		}
		pre, err := netip.ParsePrefix(p)
		if err != nil {
			a, aerr := netip.ParseAddr(p)
			if aerr != nil {
				return nil, fmt.Errorf("%q is neither an address nor a CIDR", p)
			}
			pre = netip.PrefixFrom(a, a.BitLen())
		}
		out = append(out, pre.Masked())
	}
	return out, nil
}
