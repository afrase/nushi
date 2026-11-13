package api

import (
	"net/http"

	"github.com/afrase/nushi/internal/features/tools"
)

// Handlers are the daemon's two APIs as main serves them, and as the
// end-to-end tests do: socket is the Unix socket's, the whole API behind
// the client token and a chat's tools under /tools/ behind that chat's key
// (ADR 0043), neither accepted in the other's place; devices is a paired
// device's channel's, without the Mac's own calls (ADR 0034), whose server
// gives each call its device (ConnContext: DeviceConn).
func Handlers(sv Services, t *tools.Service, token string) (socket, devices http.Handler) {
	mux := http.NewServeMux()
	mux.Handle("/tools/", Tools(t))
	mux.Handle("/", WithToken(token, New(sv)))
	return mux, ForDevices(sv)
}
