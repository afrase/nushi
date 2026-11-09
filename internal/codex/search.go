package codex

import (
	"bytes"
	"context"
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/textfind"
)

// SearchSessions finds the threads whose prompts or Codex's replies say
// s.Query, the newest first, reading the rollouts in $CODEX_HOME/sessions
// (archived ones aren't listed, so aren't read): only their messages'
// input and output text, never tool calls or their output, reasoning, the
// instructions and context Codex adds as user or developer messages, or
// compaction (ADR 0035). Forks and subagents' threads are passed over, as
// Codex's list does.
func (Local) SearchSessions(ctx context.Context, s model.SessionSearch) ([]model.SessionHit, bool, error) {
	return search(ctx, filepath.Join(Home(), "sessions"), s)
}

func search(ctx context.Context, dir string, s model.SessionSearch) ([]model.SessionHit, bool, error) {
	q := textfind.New(s.Query)
	if q.Empty() {
		return nil, false, nil
	}
	files := rollouts(dir, s.Skip)
	return textfind.Each(ctx, len(files), s.Max, func(ctx context.Context, i int) (model.SessionHit, bool) {
		h, ok := scan(ctx, files[i].path, q, s.InFolder)
		h.SessionID, h.Updated = files[i].id, files[i].modified
		return h, ok
	})
}

// rollout is a thread's rollout file.
type rollout struct {
	id, path string
	modified time.Time
}

// rollouts lists the rollouts under dir (YYYY/MM/DD/rollout-<time>-<id>.jsonl),
// the newest first, but those skip names.
func rollouts(dir string, skip func(string) bool) []rollout {
	var out []rollout
	_ = filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil //nolint:nilerr // what can't be read is skipped; the walk goes on
		}
		name := d.Name()
		if !d.Type().IsRegular() || !strings.HasPrefix(name, "rollout-") || !strings.HasSuffix(name, ".jsonl") || len(name) < 36+6 {
			return nil
		}
		id := strings.TrimSuffix(name, ".jsonl")
		id = id[len(id)-36:]
		if skip != nil && skip(id) {
			return nil
		}
		if fi, err := d.Info(); err == nil && fi.Size() > 0 {
			out = append(out, rollout{id: id, path: path, modified: fi.ModTime()})
		}
		return nil
	})
	slices.SortStableFunc(out, func(a, b rollout) int { return b.modified.Compare(a.modified) })
	return out
}

// line is what search reads of a rollout's record.
type line struct {
	Type    string `json:"type"`
	Payload struct {
		// session_meta's
		Cwd        string          `json:"cwd"`
		ForkedFrom string          `json:"forked_from_id"`
		Source     json.RawMessage `json:"source"`
		// a response_item message's
		Type    string `json:"type"`
		Role    string `json:"role"`
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	} `json:"payload"`
}

// listed says whether a thread of source is one Codex lists: a subagent's
// source is an object ({"subagent": …}), every other a name (cli, vscode,
// exec, mcp…).
func listed(source json.RawMessage) bool {
	var name string
	return len(source) == 0 || string(source) == "null" || json.Unmarshal(source, &name) == nil && !strings.HasPrefix(name, "subagent")
}

// scan reads a rollout: its session_meta first (a fork, a subagent's
// thread or one of another folder is passed over), then its messages'
// text, for the hits, the first's excerpt and its title (the first
// prompt, as Codex's list names it).
func scan(ctx context.Context, path string, q textfind.Query, inFolder func(string) bool) (model.SessionHit, bool) {
	f, err := os.Open(path) //nolint:gosec // a rollout in Codex's sessions folder
	if err != nil {
		return model.SessionHit{}, false
	}
	defer f.Close() //nolint:errcheck // read-only
	var h model.SessionHit
	first, wanted := true, true
	_ = textfind.Lines(ctx, f, func(raw []byte) bool {
		if first {
			first = false
			var meta line
			if json.Unmarshal(raw, &meta) != nil || meta.Type != "session_meta" || meta.Payload.ForkedFrom != "" ||
				!listed(meta.Payload.Source) || inFolder != nil && !inFolder(meta.Payload.Cwd) {
				wanted = false
				return false
			}
			h.Folder = meta.Payload.Cwd
			return true
		}
		// Only a message is decoded: commands' output, which is most of a
		// rollout's bytes, never is.
		if !bytes.Contains(raw, []byte(`"type":"message"`)) && !bytes.Contains(raw, []byte(`"type": "message"`)) {
			return true
		}
		title := h.Title == "" && bytes.Contains(raw, []byte(`"user"`))
		if !title && !q.MayHold(raw) {
			return true
		}
		var r line
		if json.Unmarshal(raw, &r) != nil || r.Type != "response_item" || r.Payload.Type != "message" {
			return true
		}
		for _, text := range said(r) {
			if title && r.Payload.Role == "user" && h.Title == "" {
				h.Title = strings.Join(strings.Fields(text), " ")
			}
			n, ex := q.Find(text)
			if h.Count == 0 && n > 0 {
				h.Before, h.Match, h.After = ex.Before, ex.Match, ex.After
			}
			h.Count += n
		}
		return true
	})
	return h, wanted && h.Count > 0
}

// said is a message's text the user or Codex said: a user's input_text
// that isn't context Codex added, Codex's output_text.
func said(r line) []string {
	var out []string
	for _, c := range r.Payload.Content {
		switch {
		case r.Payload.Role == "user" && c.Type == "input_text" && !added(c.Text),
			r.Payload.Role == "assistant" && c.Type == "output_text":
			out = append(out, c.Text)
		}
	}
	return out
}

// contextTag is a user message Codex writes itself, the whole text one
// tagged block: <environment_context>, <user_instructions>, a turn
// aborted.
var contextTag = regexp.MustCompile(`(?s)^<([a-z_ ]+)>.*</([a-z_ ]+)>$`)

// added says a user message's text is context Codex added, not the
// user's: a block tagged whole, or a folder's AGENTS.md.
func added(text string) bool {
	text = strings.TrimSpace(text)
	if strings.HasPrefix(text, "# AGENTS.md instructions") {
		return true
	}
	m := contextTag.FindStringSubmatch(text)
	return len(m) == 3 && m[1] == m[2]
}
