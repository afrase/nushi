package main

import (
	"bytes"
	"strings"
	"testing"
)

// A client's session with the server: each request answered in order,
// notifications and junk passed over.
func TestServe(t *testing.T) {
	in := strings.Join([]string{
		`{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"claude-code"}}}`,
		`{"jsonrpc":"2.0","method":"notifications/initialized"}`,
		`not JSON`,
		`{"jsonrpc":"2.0","id":1,"method":"tools/list"}`,
		`{"jsonrpc":"2.0","id":"c","method":"tools/call","params":{"name":"echo","arguments":{"text":"hi \"there\""}}}`,
		`{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"other","arguments":{}}}`,
		`{"jsonrpc":"2.0","id":4,"method":"resources/list"}`,
		`{"jsonrpc":"2.0","id":5,"method":"ping"}`,
	}, "\n")
	var out bytes.Buffer
	if err := serve(strings.NewReader(in), &out); err != nil {
		t.Fatal(err)
	}
	want := []string{
		`{"jsonrpc":"2.0","id":0,"result":{"capabilities":{"tools":{}},"protocolVersion":"2025-03-26","serverInfo":{"name":"mcp-echo","version":"1.0.0"}}}`,
		`{"jsonrpc":"2.0","id":1,"result":{"tools":[{"description":"Answers with the text it is given.","inputSchema":{"properties":{"text":{"description":"The text to answer with.","type":"string"}},"required":["text"],"type":"object"},"name":"echo"}]}}`,
		`{"jsonrpc":"2.0","id":"c","result":{"content":[{"text":"hi \"there\"","type":"text"}]}}`,
		`{"jsonrpc":"2.0","id":3,"error":{"code":-32602,"message":"no such tool"}}`,
		`{"jsonrpc":"2.0","id":4,"error":{"code":-32601,"message":"method not found: resources/list"}}`,
		`{"jsonrpc":"2.0","id":5,"result":{}}`,
	}
	got := strings.Split(strings.TrimSpace(out.String()), "\n")
	if len(got) != len(want) {
		t.Fatalf("got %d answers:\n%s", len(got), out.String())
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("answer %d:\n got %s\nwant %s", i, got[i], want[i])
		}
	}
}
