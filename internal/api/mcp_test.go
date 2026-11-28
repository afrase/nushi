package api

import (
	"context"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/trust"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
)

// countedChecks is an agent's MCP config with one server, which counts
// its checks: a check is the agent run in the folder, or, with elsewhere,
// in a folder of its own (Ante's `ante serve` in an empty temp folder).
type countedChecks struct {
	mcp.Config // nothing else is called
	checks     atomic.Int32
	elsewhere  bool
}

func (c *countedChecks) ChecksInFolder() bool { return !c.elsewhere }

func (*countedChecks) Servers(string) ([]model.MCPServer, error) {
	return []model.MCPServer{{Name: "s", Scope: "user", Config: `{"command":"s"}`}}, nil
}

func (c *countedChecks) Check(context.Context, string) ([]model.MCPServer, error) {
	c.checks.Add(1)
	return []model.MCPServer{{Name: "s", State: "connected"}}, nil
}

// Tech debt review 2026-11-22: the health check ran the agent (`claude mcp
// list`) in any folder a client named, before anyone saw the trust card,
// so a fresh clone's settings could run. A folder that brings code the
// agent would run is listed unchecked, saying why; a folder that brings
// nothing is checked.
func TestMcpHealthWaitsForTrust(t *testing.T) {
	cfg := &countedChecks{}
	st := store.New(t.TempDir())
	svc := chats.New(t.Context(), []chats.Kind{{Harness: model.HarnessInfo{Name: "a", Title: "A"}}},
		chats.Options{Remembered: st, Sessions: st, Scratch: t.TempDir()})
	tr := trust.New(map[string]trust.Agent{"a": hookAgent{}}, st)
	c := client(t, New(Services{Chats: svc, MCP: map[string]*mcp.Service{"a": mcp.New("a", cfg, nil)}, Trust: tr}))
	list := func(folder string) *nushiv1.ListMcpServersResponse {
		t.Helper()
		resp, err := c.ListMcpServers(t.Context(), connect.NewRequest(&nushiv1.ListMcpServersRequest{Folder: folder, CheckHealth: true, Agent: "a"}))
		testcheck.NoErr(t, err)
		return resp.Msg
	}

	brings := t.TempDir()
	testcheck.NoErr(t, os.MkdirAll(filepath.Join(brings, ".claude"), 0o700))
	testcheck.Write(t, filepath.Join(brings, ".claude", "settings.json"), `{"hooks":{}}`)
	got := list(brings)
	if cfg.checks.Load() != 0 {
		t.Fatalf("the agent ran %d checks in a folder nobody trusted", cfg.checks.Load())
	}
	if got.CheckError != notCheckedUntrusted || len(got.Servers) != 1 || got.Servers[0].State != "" {
		t.Fatalf("an untrusted folder's list = %v", got)
	}

	got = list(t.TempDir())
	if cfg.checks.Load() != 1 || got.CheckError != "" || got.Servers[0].State != "connected" {
		t.Fatalf("a folder that brings nothing: %d checks, %v", cfg.checks.Load(), got)
	}
}

// Sceptic's review 2026-11-23: the trust gate also stopped Ante's health
// check, which runs `ante serve` in an empty temp folder and never reads
// the folder named. An agent that checks elsewhere is checked in a folder
// nobody trusted; one that checks in the folder isn't.
func TestMcpHealthOfAnAgentThatChecksElsewhere(t *testing.T) {
	here, elsewhere := &countedChecks{}, &countedChecks{elsewhere: true}
	st := store.New(t.TempDir())
	svc := chats.New(t.Context(), []chats.Kind{{Harness: model.HarnessInfo{Name: "a", Title: "A"}}, {Harness: model.HarnessInfo{Name: "b", Title: "B"}}},
		chats.Options{Remembered: st, Sessions: st, Scratch: t.TempDir()})
	tr := trust.New(map[string]trust.Agent{"a": hookAgent{}, "b": hookAgent{}}, st)
	c := client(t, New(Services{Chats: svc, Trust: tr,
		MCP: map[string]*mcp.Service{"a": mcp.New("a", here, nil), "b": mcp.New("b", elsewhere, nil)}}))
	brings := t.TempDir()
	testcheck.NoErr(t, os.MkdirAll(filepath.Join(brings, ".claude"), 0o700))
	testcheck.Write(t, filepath.Join(brings, ".claude", "settings.json"), `{"hooks":{}}`)
	for _, agent := range []string{"a", "b"} {
		_, err := c.ListMcpServers(t.Context(), connect.NewRequest(&nushiv1.ListMcpServersRequest{Folder: brings, CheckHealth: true, Agent: agent}))
		testcheck.NoErr(t, err)
	}
	if here.checks.Load() != 0 || elsewhere.checks.Load() != 1 {
		t.Fatalf("checks in a folder nobody trusted: in it %d (want 0), elsewhere %d (want 1)", here.checks.Load(), elsewhere.checks.Load())
	}
}

// keylessAgent says every folder runs a hook it can't vouch for: no key,
// so "Start anyway" is never remembered (a settings file Nushi couldn't
// read, a file with no hash).
type keylessAgent struct{}

func (keylessAgent) Runs(folder string) ([]model.FolderRun, string, error) {
	return []model.FolderRun{{What: "A hook", Command: filepath.Join(folder, "hook.sh")}}, "", nil
}
func (keylessAgent) Key(string) string                      { return "" }
func (keylessAgent) Trusted(string, []string) (bool, error) { return false, nil }

// Sceptic's review 2026-11-23: a folder whose "Start anyway" is never
// remembered was told to start a chat there and choose Start anyway, which
// never brings the check back. Its servers say Nushi asks on every start.
func TestMcpHealthNotCheckedWhereNothingIsRemembered(t *testing.T) {
	cfg := &countedChecks{}
	st := store.New(t.TempDir())
	svc := chats.New(t.Context(), []chats.Kind{{Harness: model.HarnessInfo{Name: "a", Title: "A"}}},
		chats.Options{Remembered: st, Sessions: st, Scratch: t.TempDir()})
	tr := trust.New(map[string]trust.Agent{"a": keylessAgent{}}, st)
	c := client(t, New(Services{Chats: svc, MCP: map[string]*mcp.Service{"a": mcp.New("a", cfg, nil)}, Trust: tr}))
	resp, err := c.ListMcpServers(t.Context(), connect.NewRequest(&nushiv1.ListMcpServersRequest{Folder: t.TempDir(), CheckHealth: true, Agent: "a"}))
	testcheck.NoErr(t, err)
	if cfg.checks.Load() != 0 || resp.Msg.CheckError != notCheckedEveryStart {
		t.Fatalf("%d checks, check error %q", cfg.checks.Load(), resp.Msg.CheckError)
	}
}

// untrustedOne is an agent's MCP config with a project server it doesn't
// load (PiG's, in a folder it doesn't trust).
type untrustedOne struct{ mcp.Config }

func (untrustedOne) Servers(string) ([]model.MCPServer, error) {
	return []model.MCPServer{{Name: "p", Scope: "project", Config: `{"command":"p"}`, Untrusted: true},
		{Name: "u", Scope: "user", Config: `{"command":"u"}`, Held: "Set by this folder's .pig/mcp.json"}}, nil
}

func (untrustedOne) TrustsFolder(string) bool { return false }

// A project server the agent doesn't load says so, a server whose switch
// can't act says why, and the list says the agent doesn't trust the
// folder; an agent with no folder trust says nothing of it (API 157).
func TestAnUntrustedServerSaysSo(t *testing.T) {
	st := store.New(t.TempDir())
	svc := chats.New(t.Context(), []chats.Kind{{Harness: model.HarnessInfo{Name: "a", Title: "A"}}},
		chats.Options{Remembered: st, Sessions: st, Scratch: t.TempDir()})
	c := client(t, New(Services{Chats: svc, MCP: map[string]*mcp.Service{"a": mcp.New("a", untrustedOne{}, nil)}}))
	resp, err := c.ListMcpServers(t.Context(), connect.NewRequest(&nushiv1.ListMcpServersRequest{Folder: t.TempDir(), Agent: "a"}))
	testcheck.NoErr(t, err)
	if s := resp.Msg.Servers; len(s) != 2 || !s[0].Untrusted || s[1].Held != "Set by this folder's .pig/mcp.json" {
		t.Errorf("servers %v", s)
	}
	if resp.Msg.FolderTrusted == nil || *resp.Msg.FolderTrusted {
		t.Errorf("folder_trusted %v, want false", resp.Msg.FolderTrusted)
	}
	c = client(t, New(Services{Chats: svc, MCP: map[string]*mcp.Service{"a": mcp.New("a", &countedChecks{}, nil)}}))
	resp, err = c.ListMcpServers(t.Context(), connect.NewRequest(&nushiv1.ListMcpServersRequest{Folder: t.TempDir(), Agent: "a"}))
	testcheck.NoErr(t, err)
	if resp.Msg.FolderTrusted != nil {
		t.Errorf("an agent with no folder trust: folder_trusted %v", *resp.Msg.FolderTrusted)
	}
}
