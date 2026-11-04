package fakeapi_test

import (
	"bufio"
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"

	"github.com/afrase/nushi/claudeagent/claudetest/fakeapi"
)

// The fake API streams a script's turns as the Messages API does; claude
// is pointed at it with ANTHROPIC_BASE_URL and a dummy key.
func ExampleNew() {
	script := &fakeapi.Script{Turns: []fakeapi.Turn{
		{Content: []fakeapi.Block{{Type: "text", Text: "Hello!"}}},
	}}
	srv := httptest.NewServer(fakeapi.New(script, slog.New(slog.DiscardHandler)))
	defer srv.Close()

	body := `{"model":"claude-opus-5-5","stream":true,"tools":[{"name":"Bash"}],"messages":[{"role":"user","content":"hi"}]}`
	req, err := http.NewRequestWithContext(context.Background(), http.MethodPost, srv.URL+"/v1/messages", strings.NewReader(body))
	if err != nil {
		fmt.Println(err)
		return
	}
	req.Header.Set("X-Api-Key", "dummy")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		fmt.Println(err)
		return
	}
	defer func() { _ = resp.Body.Close() }()
	sc := bufio.NewScanner(resp.Body)
	for sc.Scan() {
		if event, ok := strings.CutPrefix(sc.Text(), "event: "); ok {
			fmt.Println(event)
		}
	}
	// Output:
	// message_start
	// ping
	// content_block_start
	// content_block_delta
	// content_block_stop
	// message_delta
	// message_stop
}
