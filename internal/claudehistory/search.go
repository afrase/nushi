package claudehistory

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/afrase/claude-acp-go/claudeagent/sessions"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/textfind"
)

// SearchSessions finds the sessions whose prompts or Claude's replies say
// s.Query, the newest first, reading the transcripts in s.Folder's history
// folder (every folder's for ""): only the top-level ones (a subagent's
// are in its session's own folder), and in them only the user's text and
// Claude's text blocks, never tool calls or their results, thinking, meta
// records, compaction summaries or what claude wrote in the user's place
// (ADR 0035). Forks and what Claude's list leaves out are passed over, by
// the list's own rules: forkedFrom in the first records, sessions.Store's
// reading of the transcript's start and end (a subagent's, or one with
// nothing to name it by), and claudeacp's (no folder); a session in two
// history folders is found once, by the transcript sessions.Store.Get
// reads, and its title is cut as the list cuts it.
func (l Local) SearchSessions(ctx context.Context, s model.SessionSearch) ([]model.SessionHit, bool, error) {
	q := textfind.New(s.Query)
	if q.Empty() {
		return nil, false, nil
	}
	dirs := []string{historyDir(l.Projects, s.Folder)}
	if s.Folder == "" {
		dirs = dirs[:0]
		entries, _ := os.ReadDir(l.Projects)
		for _, e := range entries {
			if e.IsDir() {
				dirs = append(dirs, filepath.Join(l.Projects, e.Name()))
			}
		}
	}
	files := transcripts(dirs, s.Skip)
	store := sessions.Store{ConfigDir: filepath.Dir(l.Projects)}
	return textfind.Each(ctx, len(files), s.Max, func(ctx context.Context, i int) (model.SessionHit, bool) {
		f := files[i]
		n, ex := scan(ctx, f.path, q)
		if n == 0 {
			return model.SessionHit{}, false
		}
		info, err := store.Get(f.id, "")
		if err != nil || info.Cwd == "" || s.InFolder != nil && !s.InFolder(info.Cwd) {
			return model.SessionHit{}, false
		}
		return model.SessionHit{SessionID: f.id, Folder: info.Cwd, Title: listTitle(info.Summary),
			Updated: f.modified, Count: n, Before: ex.Before, Match: ex.Match, After: ex.After}, true
	})
}

// transcript is a session's transcript file.
type transcript struct {
	id, path string
	modified time.Time
}

// maxTitle is the most characters of a found session's title, as
// claudeacp lists one.
const maxTitle = 256

// listTitle is a session's summary on one line, cut to maxTitle
// characters, as claudeacp's list has it (its listTitle, which it doesn't
// export): the title a chat opened from the search takes.
func listTitle(s string) string {
	s = strings.Join(strings.Fields(s), " ")
	if utf8.RuneCountInString(s) <= maxTitle {
		return s
	}
	return string([]rune(s)[:maxTitle-1]) + "…"
}

// transcripts lists the transcripts in dirs, the newest first, but those
// skip names. Of a session in more than one, the first in dirs' order,
// which is the one sessions.Store.Get finds and so where its folder and
// title come from, and what opening it resumes: its excerpt is that
// transcript's. (Claude's list keeps the newest; the two differ only for a
// session copied between history folders.)
func transcripts(dirs []string, skip func(string) bool) []transcript {
	var out []transcript
	seen := map[string]bool{}
	for _, dir := range dirs {
		entries, _ := os.ReadDir(dir)
		for _, e := range entries {
			id, ok := strings.CutSuffix(e.Name(), ".jsonl")
			if !ok || !e.Type().IsRegular() || skip != nil && skip(id) {
				continue
			}
			fi, err := e.Info()
			if err != nil || fi.Size() == 0 {
				continue
			}
			if !seen[id] {
				seen[id] = true
				out = append(out, transcript{id: id, path: filepath.Join(dir, e.Name()), modified: fi.ModTime()})
			}
		}
	}
	slices.SortStableFunc(out, func(a, b transcript) int { return b.modified.Compare(a.modified) })
	return out
}

// entry is what search reads of a transcript's record.
type entry struct {
	Type             string `json:"type"`
	IsMeta           bool   `json:"isMeta"`
	IsCompactSummary bool   `json:"isCompactSummary"`
	Message          *struct {
		Content json.RawMessage `json:"content"`
	} `json:"message"`
}

// scan counts the hits in a transcript's messages and makes the first's
// excerpt; 0 for a fork, or a file that can't be read.
func scan(ctx context.Context, path string, q textfind.Query) (int, textfind.Excerpt) {
	f, err := os.Open(path)
	if err != nil {
		return 0, textfind.Excerpt{}
	}
	defer f.Close() //nolint:errcheck // read-only
	n, first, lines := 0, textfind.Excerpt{}, 0
	_ = textfind.Lines(ctx, f, func(line []byte) bool {
		if lines++; lines <= forkLines && forkRecord(line) {
			n = 0
			return false
		}
		if !q.MayHold(line) || !mayBeSaid(line) {
			return true
		}
		var r entry
		if json.Unmarshal(line, &r) != nil || r.Message == nil || r.IsMeta || r.IsCompactSummary {
			return true
		}
		for _, text := range said(r.Type, r.Message.Content) {
			k, ex := q.Find(text)
			if n == 0 && k > 0 {
				first = ex
			}
			n += k
		}
		return true
	})
	return n, first
}

// mayBeSaid says a record may hold text the user or Claude said: a text
// block, or a prompt (a message's content as a string). A tool call's
// record, its result's or a thought's has neither and isn't decoded: those
// are most of a transcript's bytes. (A tool result whose content has text
// blocks is decoded, and passed over by said.)
func mayBeSaid(line []byte) bool {
	return has(line, "type", "text") || has(line, "content", "") && !has(line, "type", "tool_result") && !has(line, "type", "tool_use")
}

// has says line has key with a string value starting with value, as
// claude writes it (compact) or with a space after the colon.
func has(line []byte, key, value string) bool {
	return bytes.Contains(line, []byte(`"`+key+`":"`+value)) || bytes.Contains(line, []byte(`"`+key+`": "`+value))
}

// said is the text of a message the user or Claude said: a user's
// string or text blocks, cleaned of what claude adds (userText), or
// Claude's text blocks. Nothing for any other record.
func said(typ string, content json.RawMessage) []string {
	var s string
	if typ == "user" && json.Unmarshal(content, &s) == nil {
		return cleaned(s)
	}
	var blocks []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	}
	if json.Unmarshal(content, &blocks) != nil {
		return nil
	}
	var out []string
	for _, b := range blocks {
		if b.Type != "text" {
			continue
		}
		switch typ {
		case "user":
			out = append(out, cleaned(b.Text)...)
		case "assistant":
			out = append(out, b.Text)
		}
	}
	return out
}

// cleaned is a user's text as userText has it, nothing for what isn't the
// user's (claude's mark where a turn was stopped among it).
func cleaned(text string) []string {
	if claude.InterruptMark(text) {
		return nil
	}
	if t, ok := userText(text); ok {
		return []string{t}
	}
	return nil
}

// What claude writes into a user message besides what the user typed, as
// claude-acp-go's claudeacp cleans a replayed one (its userText, which it
// doesn't export): context it adds and a `!` command's output, removed
// whole, and a slash command or a `!` command as tags, which read as the
// command typed (docs/facts/claude.md).
var (
	injected = regexp.MustCompile(`(?s)<(system-reminder|task-notification|local-command-stdout|local-command-stderr|local-command-caveat|command-message|bash-stdout|bash-stderr|bash-exit-code)>.*?</(?:system-reminder|task-notification|local-command-stdout|local-command-stderr|local-command-caveat|command-message|bash-stdout|bash-stderr|bash-exit-code)>`)

	commandName = regexp.MustCompile(`(?s)<command-name>(.*?)</command-name>`)
	commandArgs = regexp.MustCompile(`(?s)<command-args>(.*?)</command-args>`)
	bashInput   = regexp.MustCompile(`(?s)<bash-input>(.*?)</bash-input>`)
)

// userText is a user message's text as the user wrote it; false when
// nothing of it is the user's.
func userText(text string) (string, bool) {
	if m := commandName.FindStringSubmatch(text); m != nil {
		name := "/" + strings.TrimPrefix(strings.TrimSpace(m[1]), "/")
		if a := commandArgs.FindStringSubmatch(text); len(a) > 1 && strings.TrimSpace(a[1]) != "" {
			name += " " + strings.TrimSpace(a[1])
		}
		return name, true
	}
	if strings.Contains(text, "<") {
		text = injected.ReplaceAllString(text, "")
		text = bashInput.ReplaceAllString(text, "!$1")
	}
	text = strings.TrimSpace(text)
	return text, text != ""
}
