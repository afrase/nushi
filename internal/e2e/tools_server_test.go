package e2e

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/daemon/daemontest"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/mcpserver"
	"github.com/afrase/nushi/internal/testcheck"
)

// newSessions are the MCP servers each session/new gave its agent, in
// order, as the agents read them off their pipes.
type newSessions struct {
	mu   sync.Mutex
	asks [][]acp.MCPServer
}

// reader is a writer of one agent's input, a line a message.
func (n *newSessions) reader() io.Writer { return &sessionLines{to: n} }

func (n *newSessions) all() [][]acp.MCPServer {
	n.mu.Lock()
	defer n.mu.Unlock()
	return slices.Clone(n.asks)
}

// sessionLines is one agent's input, its unfinished line held.
type sessionLines struct {
	to   *newSessions
	line []byte
}

func (s *sessionLines) Write(p []byte) (int, error) {
	s.line = append(s.line, p...)
	for {
		i := bytes.IndexByte(s.line, '\n')
		if i < 0 {
			return len(p), nil
		}
		var m struct {
			Method string                `json:"method"`
			Params acp.NewSessionRequest `json:"params"`
		}
		if json.Unmarshal(s.line[:i], &m) == nil && m.Method == "session/new" {
			s.to.mu.Lock()
			s.to.asks = append(s.to.asks, m.Params.MCPServers)
			s.to.mu.Unlock()
		}
		s.line = s.line[i+1:]
	}
}

// A new chat's session/new gives its agent Nushi's tools server: this
// nushid as tools-mcp, with the daemon's socket and a key the tools
// accept. Its tools are the preview's and the dev servers', never one
// that reaches GitHub: an agent can never merge through Nushi (ADR 0069,
// 0100).
func TestANewSessionGetsTheToolsServer(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	folder := t.TempDir()
	a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: folder})
	asks := d.sent.all()
	if len(asks) != 1 || len(asks[0]) != 1 || asks[0][0].Stdio == nil {
		t.Fatalf("session/new gave %+v, want the tools server", asks)
	}
	server := asks[0][0].Stdio
	env := map[string]string{}
	for _, v := range server.Env {
		env[v.Name] = v.Value
	}
	if server.Name != chats.ToolsServer || server.Command != daemontest.ToolsCommand || !slices.Equal(server.Args, []string{mcpserver.Command}) ||
		env[mcpserver.SocketEnv] != daemontest.ToolsSocket || env[mcpserver.KeyEnv] == "" {
		t.Fatalf("the tools server is %+v", server)
	}
	key := env[mcpserver.KeyEnv]

	req, err := http.NewRequestWithContext(t.Context(), http.MethodPost, d.url+"/tools/list", http.NoBody)
	testcheck.NoErr(t, err)
	req.Header.Set("Authorization", "Bearer "+key)
	resp, err := http.DefaultClient.Do(req)
	testcheck.NoErr(t, err)
	defer func() { _ = resp.Body.Close() }()
	var list struct {
		Tools []struct {
			Name string `json:"name"`
		} `json:"tools"`
	}
	testcheck.NoErr(t, json.NewDecoder(resp.Body).Decode(&list))
	var names []string
	for _, tool := range list.Tools {
		names = append(names, tool.Name)
	}
	if !slices.Contains(names, "show") || slices.ContainsFunc(names, func(n string) bool {
		return strings.Contains(n, "merge") || strings.Contains(n, "github") || strings.Contains(n, "pull")
	}) {
		t.Errorf("the chat's tools are %q", names)
	}
	testcheck.Write(t, filepath.Join(folder, "report.html"), "<h1>the report</h1>")
	if text, failed := show(t, d, key, "report.html"); failed {
		t.Errorf("the key from session/new: %q", text)
	}
}
