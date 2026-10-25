package pig

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/toolcall"
)

// Dirs is where PiG keeps its sessions: one JSON Lines file each, a header
// line ({"type":"session", id, cwd, parentSession for a fork}), then
// entries that make a tree.
// Trash is the program that moves a file to the Trash, if any.
type Dirs struct{ Sessions, Trash string }

// header is a session file's first line.
type header struct {
	Type   string `json:"type"`
	ID     string `json:"id"`
	Cwd    string `json:"cwd"`
	Parent string `json:"parentSession"`
}

// saved is a session file found, by its header.
type saved struct {
	header
	file    string
	updated time.Time
}

// all reads the header of every session file.
func (d Dirs) all() []saved {
	var out []saved
	filepath.WalkDir(d.Sessions, func(path string, e fs.DirEntry, err error) error {
		if err != nil || !e.Type().IsRegular() || !strings.HasSuffix(path, ".jsonl") {
			return nil
		}
		f, err := os.Open(path) //nolint:gosec // a session file in PiG's sessions folder, read only
		if err != nil {
			return nil
		}
		defer f.Close()
		line, _ := bufio.NewReader(io.LimitReader(f, 64<<10)).ReadBytes('\n')
		var h header
		if json.Unmarshal(line, &h) != nil || h.Type != "session" || h.ID == "" {
			return nil
		}
		fi, _ := f.Stat()
		out = append(out, saved{header: h, file: path, updated: fi.ModTime()})
		return nil
	})
	return out
}

// find is the file of the session id, which must be in folder cwd.
func (d Dirs) find(id, cwd string) (string, error) {
	for _, s := range d.all() {
		if s.ID != id {
			continue
		}
		if cwd != "" && git.RealPath(s.Cwd) != git.RealPath(cwd) {
			return "", fmt.Errorf("PiG's session %s is in %s, not %s", id, s.Cwd, cwd)
		}
		return s.file, nil
	}
	return "", fmt.Errorf("PiG has no session %s", id)
}

// remove deletes the session id's file as PiG's /resume does: to the
// Trash (`trash`, macOS's), else for good.
func (d Dirs) remove(id string) error {
	file, err := d.find(id, "")
	if err != nil {
		return nil //nolint:nilerr // not found: gone already
	}
	if d.Trash != "" {
		exec.Command(d.Trash, file).Run() //nolint:gosec // trash, on a session file PiG keeps; file is absolute
		if _, err := os.Lstat(file); errors.Is(err, fs.ErrNotExist) {
			return nil
		}
	}
	return os.Remove(file)
}

// pageSize is how many sessions a list answers at most.
const pageSize = 50

// list answers session/list: the sessions in folder cwd (every folder's
// when ""), newest first, without forks; the cursor is an offset.
func (d Dirs) list(cwd, cursor string) acp.ListSessionsResponse {
	resolved := git.RealPath(cwd)
	var found []saved
	for _, s := range d.all() {
		if s.Parent == "" && (cwd == "" || git.RealPath(s.Cwd) == resolved) {
			found = append(found, s)
		}
	}
	slices.SortFunc(found, func(a, b saved) int { return b.updated.Compare(a.updated) })
	from, _ := strconv.Atoi(cursor)
	from = min(max(from, 0), len(found))
	page := found[from:min(from+pageSize, len(found))]
	resp := acp.ListSessionsResponse{Sessions: []acp.SessionInfo{}}
	for _, s := range page {
		title, messages := summary(s.file)
		resp.Sessions = append(resp.Sessions, acp.SessionInfo{SessionID: acp.SessionID(s.ID), Cwd: s.Cwd, Title: title,
			UpdatedAt: s.updated.UTC().Format(time.RFC3339), Meta: map[string]any{"messageCount": messages}})
	}
	if next := from + len(page); next < len(found) {
		resp.NextCursor = strconv.Itoa(next)
	}
	return resp
}

// summary reads a session's title (the last name it was given, else its
// first message's first line) and how many messages it has.
func summary(file string) (title string, messages int) {
	f, err := os.Open(file) //nolint:gosec // a session file found in PiG's sessions folder
	if err != nil {
		return "", 0
	}
	defer f.Close()
	r := bufio.NewReader(f)
	var first string
	for {
		line, err := r.ReadBytes('\n')
		var e struct {
			Type    string   `json:"type"`
			Name    *string  `json:"name"`
			Message *message `json:"message"`
		}
		if json.Unmarshal(line, &e) == nil {
			switch {
			case e.Type == "session_info" && e.Name != nil:
				title = *e.Name
			case e.Type == "message" && e.Message != nil && (e.Message.Role == "user" || e.Message.Role == "assistant"):
				messages++
				if first == "" && e.Message.Role == "user" {
					var text strings.Builder
					for _, b := range e.Message.blocks() {
						text.WriteString(b.Text)
					}
					first = text.String()
				}
			}
		}
		if err != nil {
			break
		}
	}
	if title == "" {
		title, _, _ = strings.Cut(strings.TrimSpace(first), "\n")
	}
	return title, messages
}

// entry is one of a session's entries; only messages show.
type entry struct {
	Type    string   `json:"type"`
	ID      string   `json:"id"`
	Parent  *string  `json:"parentId"`
	Message *message `json:"message"`
}

// branch reads the session p holds: the entries from its root to its
// leaf, the conversation as it stands.
func branch(ctx context.Context, p *proc) ([]entry, error) {
	var r struct {
		Entries []entry `json:"entries"`
		Leaf    *string `json:"leafId"`
	}
	if err := p.call(ctx, map[string]any{"type": "get_entries"}, &r); err != nil {
		return nil, err
	}
	byID := map[string]entry{}
	for _, e := range r.Entries {
		byID[e.ID] = e
	}
	var out []entry
	for id := r.Leaf; id != nil; {
		e, ok := byID[*id]
		if !ok {
			break
		}
		out = append(out, e)
		id = e.Parent
	}
	slices.Reverse(out)
	return out, nil
}

// replay sends the client the conversation of the session pig opened:
// the user's messages, the model's (its thinking, text and calls), the
// calls' results.
func (s *session) replay(ctx context.Context) error { //nolint:gocognit // one case per kind of message and content block
	entries, err := branch(ctx, s.p)
	if err != nil {
		return err
	}
	for _, e := range entries {
		m := e.Message
		if e.Type != "message" || m == nil {
			continue
		}
		var out []acp.SessionUpdate
		switch m.Role {
		case "user":
			var b strings.Builder
			for _, block := range m.blocks() {
				b.WriteString(block.Text)
			}
			if text := b.String(); text != "" {
				out = append(out, acp.SessionUpdate{SessionUpdate: "user_message_chunk", UserMessageChunk: &acp.ContentChunk{
					Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: text}}}})
			}
		case "assistant":
			for _, b := range m.blocks() {
				switch b.Type {
				case "thinking", "text":
					if t := b.Text + b.Thinking; t != "" {
						out = append(out, chunk(b.Type == "thinking", t, messageID(m)))
					}
				case "toolCall":
					call := s.toolCall(b.ID, b.Name, b.Arguments, "in_progress", toolcall.Old{})
					out = append(out, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &call})
				}
			}
		case "toolResult":
			status := acp.ToolCallStatus("completed")
			if m.IsError {
				status = "failed"
			}
			u := acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(m.ToolCallID), Status: status}
			if kindOf(m.ToolName) != "edit" || m.IsError {
				u.Content = toolcall.Text(output(m.ToolName, resultText(m.Content)))
			}
			out = append(out, toolcall.Update(u))
		case "bashExecution": // a command the user ran (`!` in PiG's editor)
			id := "bash-" + e.ID
			call := acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: m.Command, Kind: "execute", Status: "completed", Content: toolcall.Text(toolcall.Fence(m.Output))}
			out = append(out, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &call})
		}
		for _, u := range out {
			s.b.update(s.id, u)
		}
	}
	return nil
}

// fork starts pig on the session id and forks it, whole, or after the
// turn that has the model's message after (pig forks before a message of
// the user's: the next one); pig then holds the fork, a new session.
func (b *bridge) fork(ctx context.Context, id acp.SessionID, cwd, after string) (any, error) {
	file := ""
	if s, err := b.session(id); err == nil {
		s.mu.Lock()
		file = s.file
		s.mu.Unlock()
	}
	if _, err := os.Stat(file); err != nil {
		if file, err = b.dirs.find(string(id), cwd); err != nil {
			return nil, err
		}
	}
	p, err := startProc(b.spawn, cwd, "--session", file)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, openTimeout)
	defer cancel()
	s, opts, err := b.forkOn(ctx, p, cwd, after)
	if err != nil {
		p.stop(time.Second)
		return nil, err
	}
	return acp.ForkSessionResponse{SessionID: acp.SessionID(s.id), ConfigOptions: opts}, nil
}

func (b *bridge) forkOn(ctx context.Context, p *proc, cwd, after string) (*session, []acp.SessionConfigOption, error) {
	cmd := map[string]any{"type": "clone"}
	if after != "" {
		entries, err := branch(ctx, p)
		if err != nil {
			return nil, nil, err
		}
		i := slices.IndexFunc(entries, func(e entry) bool {
			return e.Message != nil && e.Message.Role == "assistant" && messageID(e.Message) == after
		})
		if i < 0 {
			return nil, nil, errors.New("PiG's session has no such message")
		}
		for _, e := range entries[i+1:] {
			if e.Message != nil && e.Message.Role == "user" {
				cmd = map[string]any{"type": "fork", "entryId": e.ID}
				break
			}
		}
	}
	var r struct {
		Cancelled bool `json:"cancelled"`
	}
	if err := p.call(ctx, cmd, &r); err != nil {
		return nil, nil, err
	}
	if r.Cancelled {
		return nil, nil, errors.New("an extension of PiG's cancelled the fork")
	}
	return b.start(ctx, p, cwd, false)
}
