// Package mcpserver is `nushid tools-mcp`: a small MCP server over stdio
// that a chat's agent starts (Nushi names it in session/new's mcpServers),
// which lists and runs the tools the daemon grants the chat (ADR 0043).
// It knows no tool itself: it asks the daemon over its socket, with the
// chat's key from its environment.
package mcpserver

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"slices"
	"sync"
	"time"
)

// Command is the subcommand of nushid that runs it.
const Command = "tools-mcp"

// The environment the daemon gives it: its socket, and the chat's key.
const (
	SocketEnv = "NUSHI_SOCKET"
	KeyEnv    = "NUSHI_TOOLS_KEY"
)

// Main serves MCP on stdin and stdout until stdin ends.
func Main() {
	d := Daemon{Socket: os.Getenv(SocketEnv), Key: os.Getenv(KeyEnv)}
	if d.Socket == "" || d.Key == "" {
		fmt.Fprintln(os.Stderr, "nushid tools-mcp: Nushi starts this for an agent, with its socket and a key")
		os.Exit(2) //nolint:revive // a command's own exit
	}
	if err := Serve(context.Background(), os.Stdin, os.Stdout, d); err != nil {
		fmt.Fprintln(os.Stderr, "nushid tools-mcp:", err)
		os.Exit(1) //nolint:revive // as above
	}
}

// Tools is where the tools come from: the daemon (or a test's fake).
type Tools interface {
	List(ctx context.Context) (json.RawMessage, error)
	Call(ctx context.Context, name string, args json.RawMessage) (text string, failed bool, err error)
}

// versions are the MCP versions it speaks; a client asking another gets
// the newest.
var versions = []string{"2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"}

type message struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// Serve answers MCP requests from in on out, a JSON-RPC message a line,
// each request in a goroutine of its own (a slow tool doesn't hold up a
// ping).
func Serve(ctx context.Context, in io.Reader, out io.Writer, tools Tools) error {
	var mu sync.Mutex
	send := func(v any) {
		b, err := json.Marshal(v)
		if err != nil {
			return
		}
		mu.Lock()
		defer mu.Unlock()
		_, _ = out.Write(append(b, '\n')) // a closed stdout ends the agent's side too
	}
	var wg sync.WaitGroup
	defer wg.Wait()
	sc := bufio.NewScanner(in)
	sc.Buffer(make([]byte, 64<<10), 16<<20)
	for sc.Scan() {
		line := bytes.TrimSpace(sc.Bytes())
		if len(line) == 0 {
			continue
		}
		var m message
		if err := json.Unmarshal(line, &m); err != nil {
			send(map[string]any{"jsonrpc": "2.0", "id": nil, "error": rpcError{-32700, "parse error"}})
			continue
		}
		if len(m.ID) == 0 { // a notification (initialized, cancelled): nothing to answer
			continue
		}
		wg.Go(func() {
			result, err := handle(ctx, m, tools)
			if err != nil {
				var re *rpcError
				if !errors.As(err, &re) {
					re = &rpcError{-32603, err.Error()}
				}
				send(map[string]any{"jsonrpc": "2.0", "id": m.ID, "error": re})
				return
			}
			send(map[string]any{"jsonrpc": "2.0", "id": m.ID, "result": result})
		})
	}
	return sc.Err()
}

func (e *rpcError) Error() string { return e.Message }

func handle(ctx context.Context, m message, tools Tools) (any, error) {
	switch m.Method {
	case "initialize":
		var p struct {
			ProtocolVersion string `json:"protocolVersion"`
		}
		_ = json.Unmarshal(m.Params, &p) // no version asked: the newest
		v := versions[len(versions)-1]
		if slices.Contains(versions, p.ProtocolVersion) {
			v = p.ProtocolVersion
		}
		return map[string]any{
			"protocolVersion": v,
			"capabilities":    map[string]any{"tools": map[string]any{}},
			"serverInfo":      map[string]any{"name": "nushi", "title": "Nushi", "version": "1"},
		}, nil
	case "ping":
		return map[string]any{}, nil
	case "tools/list":
		list, err := tools.List(ctx)
		if err != nil {
			return nil, err
		}
		return map[string]any{"tools": list}, nil
	case "tools/call":
		var p struct {
			Name      string          `json:"name"`
			Arguments json.RawMessage `json:"arguments"`
		}
		if err := json.Unmarshal(m.Params, &p); err != nil || p.Name == "" {
			return nil, &rpcError{-32602, "tools/call needs a tool's name"}
		}
		text, failed, err := tools.Call(ctx, p.Name, p.Arguments)
		if err != nil {
			text, failed = err.Error(), true // the agent sees the tool fail, and why
		}
		return map[string]any{"content": []map[string]string{{"type": "text", "text": text}}, "isError": failed}, nil
	}
	return nil, &rpcError{-32601, "no method " + m.Method}
}

// Daemon is the daemon's tools, asked over its socket (HTTP/2 without
// TLS, as the app talks to it) with the chat's key.
type Daemon struct {
	Socket, Key string
}

func (d Daemon) client() *http.Client {
	p := new(http.Protocols)
	p.SetUnencryptedHTTP2(true)
	return &http.Client{Timeout: 2 * time.Minute, Transport: &http.Transport{
		Protocols: p,
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			return new(net.Dialer).DialContext(ctx, "unix", d.Socket)
		},
	}}
}

func (d Daemon) post(ctx context.Context, path string, body, out any) error {
	b, err := json.Marshal(body)
	if err != nil {
		return err
	}
	// Plain HTTP/2 on the daemon's Unix socket; the host isn't looked up.
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://nushid"+path, bytes.NewReader(b)) //nolint:revive // as the app's socket transport

	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+d.Key)
	req.Header.Set("Content-Type", "application/json")
	resp, err := d.client().Do(req)
	if err != nil {
		return fmt.Errorf("can't reach Nushi: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		msg, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("nushi: %s", bytes.TrimSpace(msg))
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

// List asks the daemon for the chat's tools.
func (d Daemon) List(ctx context.Context) (json.RawMessage, error) {
	var r struct {
		Tools json.RawMessage `json:"tools"`
	}
	err := d.post(ctx, "/tools/list", struct{}{}, &r)
	return r.Tools, err
}

// Call asks the daemon to run one.
func (d Daemon) Call(ctx context.Context, name string, args json.RawMessage) (string, bool, error) {
	var r struct {
		Text    string `json:"text"`
		IsError bool   `json:"isError"`
	}
	err := d.post(ctx, "/tools/call", map[string]any{"name": name, "arguments": args}, &r)
	return r.Text, r.IsError, err
}
