package launchfile

import (
	"strings"
	"testing"
)

// A url is checked by Claude's rules, its host read as a browser reads it.
func TestParseURL(t *testing.T) {
	for _, c := range []struct {
		url  string
		want target
	}{
		{"http://localhost:3000", target{href: "http://localhost:3000/", host: "localhost:3000", local: true, port: 3000}},
		{"HTTP://LocalHost:3000/", target{href: "http://localhost:3000/", host: "localhost:3000", local: true, port: 3000}},
		{" https://app.localhost ", target{href: "https://app.localhost/", host: "app.localhost", local: true, port: 443}},
		{"http://localhost:80", target{href: "http://localhost/", host: "localhost", local: true, port: 80}},
		{"http://127.0.0.1:8000", target{href: "http://127.0.0.1:8000/", host: "127.0.0.1:8000", local: true, port: 8000}},
		{"http://127.1:8000", target{href: "http://127.0.0.1:8000/", host: "127.0.0.1:8000", local: true, port: 8000}},
		{"http://0x7f.0.0.1:8000", target{href: "http://127.0.0.1:8000/", host: "127.0.0.1:8000", local: true, port: 8000}},
		{"http://2130706433:8000", target{href: "http://127.0.0.1:8000/", host: "127.0.0.1:8000", local: true, port: 8000}},
		{"http://0.0.0.0:3000", target{href: "http://0.0.0.0:3000/", host: "0.0.0.0:3000", local: true, port: 3000}},
		{"http://[::1]:3000", target{href: "http://[::1]:3000/", host: "[::1]:3000", local: true, port: 3000}},
		{"http://[0:0:0:0:0:0:0:1]:3000", target{href: "http://[::1]:3000/", host: "[::1]:3000", local: true, port: 3000}},
		{"http://@localhost:3000", target{href: "http://localhost:3000/", host: "localhost:3000", local: true, port: 3000}},
		{"https://Example.com/sign-in?next=%2F#top", target{href: "https://example.com/sign-in?next=%2F#top", host: "example.com", port: 443}},
		{"http://192.168.1.4:8080/app", target{href: "http://192.168.1.4:8080/app", host: "192.168.1.4:8080", port: 8080}},
		{"http://my.localhost.example.com", target{href: "http://my.localhost.example.com", host: "my.localhost.example.com", port: 80}},
	} {
		got, err := parseURL(c.url)
		if err != nil || got != c.want {
			t.Errorf("%q: %+v, %v; want %+v", c.url, got, err, c.want)
		}
	}
	for _, c := range []struct{ url, err string }{
		{"file:///tmp/a.html", "must be http or https"},
		{"localhost:3000", "must be http or https"},
		{"ws://localhost:3000", "must be http or https"},
		{"http://me:pw@localhost:3000", "user name or password"},
		{"http://:pw@localhost:3000", "user name or password"},
		{"http://me@example.com", "user name or password"},
		{"http://localhost:3000/admin", "the server's origin alone"},
		{"http://127.0.0.1:3000/?x=1", "the server's origin alone"},
		{"http://[::1]:3000/#top", "the server's origin alone"},
		{"http://app.localhost/index.html", "the server's origin alone"},
		{"http://localhost.:3000", "not written the usual way"},
		{"http://app.localhost..", "not written the usual way"},
		{"http://127.0.0.2:3000", "not written the usual way"},
		{"http://127.2:3000", "not written the usual way"},
		{"http://[::ffff:127.0.0.1]:3000", "not written the usual way"},
		{"http://[::ffff:7f00:1]:3000", "not written the usual way"},
		{"http://localhost:70000", "not a valid URL"},
		{"http://", "not a valid URL"},
		{"http:localhost", "not a valid URL"},
		{"http://[fe80::1%25en0]:3000", "not a valid URL"},
		{"http://256.0.0.1", "not a valid URL"},
		{"http://1.2.3.4.5", "not a valid URL"},
		{"http://1.2.65536", "not a valid URL"},
	} {
		if got, err := parseURL(c.url); err == nil || !strings.Contains(err.Error(), c.err) {
			t.Errorf("%q: %+v, %v; want %q", c.url, got, err, c.err)
		}
	}
}
