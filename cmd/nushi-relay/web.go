package main

import (
	"embed"
	"errors"
	"io/fs"

	"github.com/afrase/nushi/relay"
)

// built holds the phone's web app when the relay was built with it (ADR
// 0113): a release copies the built app into web/ first (tools/release.sh,
// make relay-web). Built from the repository as it is, web/ has only its
// placeholder and the relay has no app of its own.
//
//go:embed all:web
var built embed.FS

// builtIn is the web app built into this relay, or nil when it has none.
func builtIn() fs.FS {
	app, err := fs.Sub(built, "web")
	if err != nil {
		return nil
	}
	return builtInFrom(app)
}

// builtInFrom is app if it is a built web app (it has a page), else nil.
func builtInFrom(app fs.FS) fs.FS {
	if app == nil {
		return nil
	}
	if _, err := fs.Stat(app, "index.html"); err != nil {
		return nil
	}
	return app
}

// site is the web app to serve, or nil for a relay that only copies
// messages: the app in the folder dir (-web), else the one built in, at
// origin (-origin; with -web and -host, https://<host> unless given).
// Without an origin nothing is served, so a relay run as before serves
// what it did.
func site(dir, origin, host string, app fs.FS) (*relay.Site, error) {
	if origin == "" && dir != "" && host != "" {
		origin = "https://" + host
	}
	switch {
	case dir != "":
		return relay.LoadSite(dir, origin)
	case origin == "":
		return nil, nil //nolint:nilnil // no app to serve isn't an error
	case app == nil:
		return nil, errors.New("this relay was built without the web app: give its folder with -web (make web builds it), or use a release's relay")
	}
	return relay.NewSite(app, origin)
}
