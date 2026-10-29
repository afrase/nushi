package main

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"syscall"
	"testing"
	"time"
)

// childAgent answers session/new with a session, then announces a
// subagent's session on it; it returns what it got, once r ends.
func childAgent(r io.Reader, w io.Writer) <-chan []map[string]any {
	done := make(chan []map[string]any, 1)
	go func() {
		var got []map[string]any
		sc := bufio.NewScanner(r)
		for sc.Scan() {
			var m map[string]any
			_ = json.Unmarshal(sc.Bytes(), &m)
			got = append(got, m)
			id, _ := json.Marshal(m["id"])
			switch m["method"] {
			case "session/new":
				_, _ = io.WriteString(w, `{"jsonrpc":"2.0","id":`+string(id)+`,"result":{"sessionId":"sid-1"}}`+"\n")
				_, _ = io.WriteString(w, `{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"sid-1","update":{"sessionUpdate":"subagent_update","sessionId":"child-1","state":{"state":"running"}}}}`+"\n")
			case "session/fork":
				_, _ = io.WriteString(w, `{"jsonrpc":"2.0","id":`+string(id)+`,"result":{"sessionId":"sid-2"}}`+"\n")
			}
		}
		done <- got
	}()
	return done
}

// A step can name a value of a message it waited for (a subagent's
// session, which a later step cancels), give MCP servers with
// "$mcp-echo", stop a process, and have claude's history kept before a
// fork.
func TestPlayCapturesAndHooks(t *testing.T) {
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	agent := childAgent(toAgentR, fromAgentW)
	c := newConn(toAgentW, fromAgentR, io.Discard)
	var s []step
	err := json.Unmarshal([]byte(`[
		{"new": "s1", "mcpServers": [{"name": "echo", "command": "$mcp-echo", "args": ["$s1"], "env": []}]},
		{"waitFor": {"params": {"update": {"sessionUpdate": "subagent_update"}}}, "capture": {"child": "params.update.sessionId"}},
		{"cancel": "child"},
		{"kill": "sleep 37"},
		{"fork": "s1", "as": "f"}
	]`), &s)
	if err != nil {
		t.Fatal(err)
	}
	var killed []string
	snapshots := 0
	p := &player{c: c, cwd: "/work", timeout: 5 * time.Second, ids: map[string]string{}, vars: map[string]string{"mcp-echo": "/bin/mcp-echo"},
		async: map[string]<-chan msg{}, snapshot: func() error { snapshots++; return nil },
		kill: func(_ context.Context, text string) error { killed = append(killed, text); return nil }}
	if err := p.play(t.Context(), s); err != nil {
		t.Fatal(err)
	}
	_ = toAgentW.Close()
	got := <-agent
	_ = fromAgentW.Close()
	<-c.done
	if len(got) != 3 {
		t.Fatalf("the agent got %v", got)
	}
	servers, _ := json.Marshal(got[0]["params"].(map[string]any)["mcpServers"])
	if string(servers) != `[{"args":["$s1"],"command":"/bin/mcp-echo","env":[],"name":"echo"}]` {
		t.Errorf("mcpServers %s", servers) // "$s1" isn't a session yet when new is sent
	}
	if got[1]["method"] != "session/cancel" || got[1]["params"].(map[string]any)["sessionId"] != "child-1" {
		t.Errorf("the cancel: %v", got[1])
	}
	if !slices.Equal(killed, []string{"sleep 37"}) || snapshots != 1 {
		t.Errorf("killed %q, %d snapshots", killed, snapshots)
	}
}

// At an end step the client goes at once: the steps after it don't run,
// and a prompt it didn't await isn't waited for.
func TestPlayEnd(t *testing.T) {
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	agent := childAgent(toAgentR, fromAgentW) // it never answers a prompt
	c := newConn(toAgentW, fromAgentR, io.Discard)
	var s []step
	if err := json.Unmarshal([]byte(`[{"new": "s1"}, {"prompt": "hi", "session": "s1", "async": "p1"}, {"end": {}}, {"cancel": "s1"}]`), &s); err != nil {
		t.Fatal(err)
	}
	p := &player{c: c, cwd: "/work", timeout: time.Hour, ids: map[string]string{}, async: map[string]<-chan msg{}}
	if err := p.play(t.Context(), s); err != nil {
		t.Fatal(err)
	}
	_ = toAgentW.Close()
	got := <-agent
	_ = fromAgentW.Close()
	<-c.done
	if len(got) != 2 || got[1]["method"] != "session/prompt" {
		t.Errorf("the agent got %v", got)
	}
}

// A script that names a session before any step made it doesn't load.
func TestLoadClientNames(t *testing.T) {
	for _, tc := range []struct {
		steps string
		ok    bool
	}{
		{`[{"new": "s1"}, {"prompt": "hi", "session": "s1"}, {"fork": "s1", "as": "s2"}, {"load": "s2"}]`, true},
		{`[{"waitFor": {}, "capture": {"c": "params.update.sessionId"}}, {"cancel": "c"}]`, true},
		{`[{"prompt": "hi", "session": "s1"}]`, false},
		{`[{"new": "s1"}, {"close": "s2"}]`, false},
		{`[{"cancel": "c"}, {"waitFor": {}, "capture": {"c": "x"}}]`, false},
	} {
		dir := t.TempDir()
		if err := os.WriteFile(filepath.Join(dir, "client.json"), []byte(`{"steps":`+tc.steps+`}`), 0o600); err != nil {
			t.Fatal(err)
		}
		if _, _, err := loadClient(dir); (err == nil) != tc.ok {
			t.Errorf("%s: %v", tc.steps, err)
		}
	}
}

// claude's history is copied as it is, but for each project's memory, and
// without the projects' folders.
func TestHistory(t *testing.T) {
	projects := filepath.Join(t.TempDir(), "projects")
	for name, body := range map[string]string{
		"-tmp-work/s1.jsonl":                        "a\n",
		"-tmp-work/s1/subagents/agent-a1.jsonl":     "b\n",
		"-tmp-work/s1/subagents/agent-a1.meta.json": "{}",
		"-tmp-work/memory/MEMORY.md":                "no",
	} {
		p := filepath.Join(projects, name)
		if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	dst := filepath.Join(t.TempDir(), "history", "1")
	if err := history(projects, dst); err != nil {
		t.Fatal(err)
	}
	var got []string
	_ = filepath.WalkDir(dst, func(path string, d os.DirEntry, _ error) error {
		if !d.IsDir() {
			rel, _ := filepath.Rel(dst, path)
			got = append(got, rel)
		}
		return nil
	})
	slices.Sort(got)
	if want := []string{"s1.jsonl", "s1/subagents/agent-a1.jsonl", "s1/subagents/agent-a1.meta.json"}; !slices.Equal(got, want) {
		t.Errorf("copied %q", got)
	}
	if err := history(filepath.Join(t.TempDir(), "none"), dst); err != nil {
		t.Errorf("no projects folder yet: %v", err)
	}
}

// A kill stops the group of the process below the agent whose command
// line says so, and no other.
func TestStopBelow(t *testing.T) {
	start := func(script string) *exec.Cmd {
		cmd := exec.CommandContext(t.Context(), "/bin/sh", "-c", script)
		cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true} // as claude starts a command
		if err := cmd.Start(); err != nil {
			t.Fatal(err)
		}
		return cmd
	}
	other := start("sleep 59; echo other")
	target := start("sleep 58; echo target")
	if err := stopBelow(t.Context(), os.Getpid(), "echo target", 5*time.Second); err != nil {
		t.Fatal(err)
	}
	if err := target.Wait(); err == nil || !strings.Contains(err.Error(), "terminated") {
		t.Errorf("the target ended with %v", err)
	}
	if other.ProcessState != nil {
		t.Error("the other ended")
	}
	_ = other.Process.Kill()
	_ = other.Wait()
	if err := stopBelow(t.Context(), os.Getpid(), "echo nobody", 200*time.Millisecond); err == nil {
		t.Error("stopped a process no one runs")
	}
}
