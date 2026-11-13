package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/tools"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/testcheck"
)

// The socket's API takes the client token and nothing else, a chat's tools
// take that chat's key and nothing else, and a device's channel never pairs
// a device: the handlers as main serves them (Handlers), so dropping one of
// those checks from the wiring fails here.
func TestHandlersAsServed(t *testing.T) {
	ts := tools.New()
	key := ts.Key(tools.Grant{Chat: "c", Agent: "fake"})
	socket, devices := Handlers(Services{}, ts, "tok")
	srv := httptest.NewServer(socket)
	t.Cleanup(srv.Close)
	ctx := context.Background()

	c := nushiv1connect.NewNushiServiceClient(http.DefaultClient, srv.URL)
	ping := func(bearer string) error {
		req := connect.NewRequest(&nushiv1.PingRequest{})
		if bearer != "" {
			req.Header().Set("Authorization", "Bearer "+bearer)
		}
		_, err := c.Ping(ctx, req)
		return err
	}
	if err := ping("tok"); err != nil {
		t.Fatalf("the client token: %v", err)
	}
	for name, bearer := range map[string]string{"no token": "", "a chat's tools key": key} {
		if err := ping(bearer); connect.CodeOf(err) != connect.CodeUnauthenticated {
			t.Errorf("%s on the API: %v, want unauthenticated", name, err)
		}
	}

	list := func(bearer string) int {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, srv.URL+"/tools/list", strings.NewReader("{}"))
		testcheck.NoErr(t, err)
		req.Header.Set("Authorization", "Bearer "+bearer)
		resp, err := http.DefaultClient.Do(req)
		testcheck.NoErr(t, err)
		_ = resp.Body.Close()
		return resp.StatusCode
	}
	if got := list(key); got != http.StatusOK {
		t.Errorf("the chat's key on its tools: %d", got)
	}
	if got := list("tok"); got != http.StatusUnauthorized {
		t.Errorf("the client token on a chat's tools: %d, want 401", got)
	}

	d := client(t, devices)
	if _, err := d.Ping(ctx, connect.NewRequest(&nushiv1.PingRequest{})); err != nil {
		t.Errorf("a device's ping: %v", err)
	}
	if _, err := d.StartPairing(ctx, connect.NewRequest(&nushiv1.StartPairingRequest{})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("a device pairing another: %v, want permission denied", err)
	}
}
