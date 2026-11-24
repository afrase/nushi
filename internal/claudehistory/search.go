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
// nothing to name it by), and claudeacp's (no folder). A hit's folder and
// title are those of the transcript that was read, the title cut as the
// list cuts it; searching every folder, a session with a transcript in
// more than one is found once, by the one Claude's list of every folder
// tells of (see transcripts).
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
	return textfind.Each(ctx, len(files), s.Max, func(ctx context.Context, i int) (model.SessionHit, bool) {
		f := files[i]
		n, ex := scan(ctx, f.path, q, s.Unnoted)
		if n == 0 {
			return model.SessionHit{}, false
		}
		info, err := sessions.ReadInfo(f.path)
		if err != nil || info.Cwd == "" || s.InFolder != nil && !s.InFolder(info.Cwd) {
			return model.SessionHit{}, false
		}
		title := info.Summary
		if s.Unnoted != nil {
			title = s.Unnoted(title) // the first prompt's first text block may be a note
		}
		return model.SessionHit{SessionID: f.id, Folder: info.Cwd, Title: sessions.ListTitle(title),
			Updated: f.modified, Count: n, Before: ex.Before, Match: ex.Match, After: ex.After}, true
	})
}

// transcript is a session's transcript file.
type transcript struct {
	id, path string
	modified time.Time
}

// transcripts lists the transcripts in dirs, the newest first, but those
// skip names. Of a session in more than one, the newest that Claude's list
// would tell of, as that list keeps it (sessions.Store.List): a session
// continued from another folder has a transcript in each, and one of them
// may be a start with nothing said yet.
func transcripts(dirs []string, skip func(string) bool) []transcript {
	var out []transcript
	at := map[string]int{}
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
			t := transcript{id: id, path: filepath.Join(dir, e.Name()), modified: fi.ModTime()}
			if i, ok := at[id]; !ok {
				at[id] = len(out)
				out = append(out, t)
			} else if listed(t) && (t.modified.After(out[i].modified) || !listed(out[i])) {
				out[i] = t
			}
		}
	}
	slices.SortStableFunc(out, func(a, b transcript) int { return b.modified.Compare(a.modified) })
	return out
}

// listed says Claude's list would tell of t: it isn't a subagent's and
// has something to name it by. Asked only of a session's second transcript
// and those it is weighed against.
func listed(t transcript) bool {
	_, err := sessions.ReadInfo(t.path)
	return err == nil
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
// excerpt; 0 for a fork, or a file that can't be read. unnoted (nil: none)
// takes Nushi's notes off each text of the user's.
func scan(ctx context.Context, path string, q textfind.Query, unnoted func(string) string) (int, textfind.Excerpt) {
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
		if !q.MayHold(line) && !typed(line) || !mayBeSaid(line) {
			return true
		}
		var r entry
		if json.Unmarshal(line, &r) != nil || r.Message == nil || r.IsMeta || r.IsCompactSummary {
			return true
		}
		for _, text := range said(r.Type, r.Message.Content, unnoted) {
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

// typed says a record may hold a command the user typed, which cleaned
// writes with a `!` or `/` the line may not have ("!git" for
// <bash-input>git status</bash-input>): the query's anchor can't rule it
// out, so it is decoded.
func typed(line []byte) bool {
	return bytes.Contains(line, []byte("<bash-input>")) || bytes.Contains(line, []byte("<command-name>"))
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
// string or text blocks, cleaned of what claude adds (cleaned), or
// Claude's text blocks. Nothing for any other record.
func said(typ string, content json.RawMessage, unnoted func(string) string) []string {
	var s string
	if typ == "user" && json.Unmarshal(content, &s) == nil {
		return cleaned(s, unnoted)
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
			out = append(out, cleaned(b.Text, unnoted)...)
		case "assistant":
			out = append(out, b.Text)
		}
	}
	return out
}

// cleaned is a user's text as a replay shows it (sessions.UserText),
// without Nushi's notes (unnoted, when not nil), with a `!` command as
// the app shows it (bashText); nothing for what isn't the user's (claude's
// mark where a turn was stopped among it).
func cleaned(text string, unnoted func(string) string) []string {
	if claude.InterruptMark(text) {
		return nil
	}
	if unnoted != nil {
		text = unnoted(text)
	}
	if t, ok := sessions.UserText(bashText(text)); ok {
		return []string{t}
	}
	return nil
}

// A `!` command's tags, which sessions.UserText leaves in on purpose: the
// app shows them as a run (app/lib/run_text.dart), the command as typed
// after a `!` and its output in the run's card, not as the user's words,
// so search matches the command as `!X` and passes over the output. Each
// runs to the nearest closing tag of its own name; one with none after it
// is the user's text, as UserText has a marker.
var (
	bashInput  = regexp.MustCompile(`(?s)<bash-input>(.*?)</bash-input>`)
	bashOutput = regexp.MustCompile(`(?s)<bash-stdout>.*?</bash-stdout>|<bash-stderr>.*?</bash-stderr>|<bash-exit-code>.*?</bash-exit-code>`)
)

// bashText is text with a `!` command as the app shows it: the command
// as typed, "!" and all, and its output left out.
func bashText(text string) string {
	if !strings.Contains(text, "<bash-") {
		return text
	}
	return bashInput.ReplaceAllString(bashOutput.ReplaceAllString(text, ""), "!$1")
}
