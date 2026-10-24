package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
)

func TestPingNeedsToken(t *testing.T) {
	srv := httptest.NewServer(Handler("secret", nil, nil, nil, nil, nil, nil))
	defer srv.Close()

	ping := func(token string) error {
		c := nushiv1connect.NewNushiServiceClient(http.DefaultClient, srv.URL)
		req := connect.NewRequest(&nushiv1.PingRequest{})
		if token != "" {
			req.Header().Set("Authorization", "Bearer "+token)
		}
		_, err := c.Ping(context.Background(), req)
		return err
	}
	if err := ping("secret"); err != nil {
		t.Fatalf("ping with token: %v", err)
	}
	for _, tok := range []string{"", "wrong"} {
		if err := ping(tok); connect.CodeOf(err) != connect.CodeUnauthenticated {
			t.Errorf("ping with %q: got %v, want unauthenticated", tok, err)
		}
	}
}
