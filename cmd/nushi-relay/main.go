// Command nushi-relay is the relay a Nushi daemon and its phones meet
// through. It copies end-to-end encrypted messages between two connections
// that name the same random id, and keeps nothing: no accounts, no disk,
// no logs beyond starting and fatal errors.
package main

import (
	"cmp"
	"flag"
	"io"
	"log"
	"net"
	"net/http"
	"time"

	"golang.org/x/crypto/acme/autocert"

	"github.com/afrase/nushi/relay"
)

func main() {
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
	flag.IntVar(&lim.PerID, "per-id", lim.PerID, "connections on one id")
	flag.IntVar(&lim.Total, "total", lim.Total, "connections in all")
	flag.Parse()

	srv := &http.Server{Handler: relay.New(lim), ReadHeaderTimeout: 10 * time.Second, MaxHeaderBytes: 8 << 10,
		ErrorLog: log.New(io.Discard, "", 0)} // its messages name clients' addresses
	if *host == "" {
		ln, err := net.Listen("tcp", cmp.Or(*addr, ":8080"))
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
	ln, err := net.Listen("tcp", cmp.Or(*addr, ":443"))
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("nushi-relay listening on %s, TLS for %s", ln.Addr(), *host)
	log.Fatal(srv.ServeTLS(ln, "", ""))
}
