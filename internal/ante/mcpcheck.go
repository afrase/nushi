package ante

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"strings"
	"syscall"
)

// Server is a Spawn of bin (`ante serve --stdio`) with env, its stderr
// dropped, in a process group of its own (so the MCP servers it starts go
// with it).
func Server(bin string, env []string) Spawn {
	return func(cwd string) (io.WriteCloser, io.Reader, func(), error) {
		cmd := exec.Command(bin, "serve", "--stdio") //nolint:noctx // killed by the check, whose context ends it
		cmd.Dir, cmd.Env = cwd, env
		cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
		in, err := cmd.StdinPipe()
		if err != nil {
			return nil, nil, nil, err
		}
		out, err := cmd.StdoutPipe()
		if err != nil {
			return nil, nil, nil, err
		}
		if err := cmd.Start(); err != nil {
			return nil, nil, nil, err
		}
		exited := make(chan struct{})
		go func() { _ = cmd.Wait(); close(exited) }() // its end is all that matters here
		return in, out, func() {
			_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) // the group may be gone already
			<-exited
		}, nil
	}
}

// CheckMCP has a throwaway Ante host connect to your MCP servers and says
// how each went, by name: "" for one that connected, else Ante's words on
// why it failed (a name it doesn't list is left out). The session starts
// in an empty folder (Ante reads no project's MCP servers) and gets no
// input, so Ante saves nothing. Ante 0.2.14 tells only in its warm-up
// notice: InfoBlock "mcp-warmup-<session>" has a line "MCP server '<name>'
// failed: <why>" per failure and ends with "MCP ready: …" (or "MCP
// warm-up: 0/n …" when none connected); ExtensionRefreshed lists the
// servers. A server that hangs fails after Ante's 15 s. With no servers
// there is no notice: don't ask then.
func CheckMCP(ctx context.Context, spawn Spawn) (map[string]string, error) {
	dir, err := os.MkdirTemp("", "nushi-ante-mcp-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir) //nolint:errcheck // a temp folder
	h, err := startHost(spawn, dir)
	if err != nil {
		return nil, err
	}
	defer func() { h.kill(); <-h.exited }()
	if err := h.send(map[string]any{"StartSession": map[string]any{"cwd": dir}}); err != nil {
		return nil, err
	}
	w := warmup{out: map[string]string{}}
	for {
		select {
		case <-ctx.Done():
			return nil, errors.New("Ante didn't finish connecting to its MCP servers in time")
		case ev, ok := <-h.events:
			if !ok {
				return nil, errors.New("Ante stopped before it connected to its MCP servers")
			}
			if w.take(ev) {
				return w.out, nil
			}
		}
	}
}

// warmup reads a session's MCP warm-up: the servers by name, "" or why one
// failed.
type warmup struct {
	block string // the notice's id, once the session started
	out   map[string]string
}

// take reads one event; true once the warm-up is over.
func (w *warmup) take(ev event) bool {
	switch ev.Name {
	case "SessionStart":
		var s struct {
			SessionID string `json:"session_id"`
		}
		_ = json.Unmarshal(ev.Payload, &s)
		w.block = "mcp-warmup-" + s.SessionID
	case "ExtensionRefreshed":
		var r struct {
			Servers []struct {
				Name string `json:"name"`
			} `json:"mcp_servers"`
		}
		_ = json.Unmarshal(ev.Payload, &r)
		for _, s := range r.Servers {
			if _, seen := w.out[s.Name]; !seen {
				w.out[s.Name] = ""
			}
		}
	case "InfoBlockAppend":
		var a struct {
			ID     string `json:"id"`
			Detail string `json:"detail"`
		}
		_ = json.Unmarshal(ev.Payload, &a)
		if a.ID != w.block || w.block == "" {
			return false
		}
		if strings.HasPrefix(a.Detail, "MCP ready:") || strings.HasPrefix(a.Detail, "MCP warm-up:") {
			return true
		}
		if rest, ok := strings.CutPrefix(a.Detail, "MCP server '"); ok {
			if name, why, ok := strings.Cut(rest, "' failed: "); ok {
				w.out[name] = why
			}
		}
	}
	return false
}
