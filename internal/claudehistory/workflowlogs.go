package claudehistory

import (
	"bytes"
	"encoding/json"
	"io"
	"os"
	"path"
	"time"

	"github.com/afrase/nushi/internal/regularfile"
)

// A workflow's agents write nothing to claude's output and aren't a chat's
// turns (ADR 0136), so what the card shows of them while the run goes is
// read from their own transcripts, each as it grows, in one pass: their
// tokens (#103), as claude counts a subagent's totalTokens, its last
// message's input, cache and output tokens (docs/facts/claude.md), and the
// files they wrote (workflowwritten.go). Once the run ended its snapshot's
// own total stands; the files are read to the end once more.

// agentLog is what was read of one agent's transcript, read as it grows
// (lines): its last message's tokens, the files it wrote, and the
// worktree Claude gave it (its sidecar's). final says
// it was read after its agent ended: nothing more comes.
type agentLog struct {
	lines
	tokens int64
	final  bool
	read   int64 // the bytes read of it in all
	files  agentFiles
	file   os.FileInfo // the file read last: another in its place is read anew
	// begun says its first line was read, since is that line's time, and
	// worktree the worktree its sidecar names (workflowworktrees.go);
	// metaRead says the sidecar is read no more.
	begun    bool
	since    time.Time
	worktree string
	metaRead bool
}

// readLog reads what the transcript (f, as fi) added since the last; one
// shorter than what was read, or another file in its place (Claude only
// appends, so neither is expected), is read from its start.
func (a *agentLog) readLog(f io.ReaderAt, fi os.FileInfo) error {
	if fi.Size() < a.off || a.file != nil && !os.SameFile(a.file, fi) { // rewritten
		*a = agentLog{read: a.read}
	}
	a.file = fi
	from := a.off
	a.files.mod = fi.ModTime()
	err := a.lines.read(f, min(fi.Size(), maxAgentLog), maxStepLine, a.line)
	a.read += a.off - from
	return err
}

// line takes one line of the transcript: an assistant message's usage,
// when it has any, is the agent's tokens now; its file tools' calls and
// their results are the files it wrote.
func (a *agentLog) line(line []byte) {
	if !a.begun {
		var first struct {
			Timestamp string `json:"timestamp"`
		}
		_ = json.Unmarshal(line, &first) // none: the transcript's time
		a.begin(first.Timestamp)
	}
	usage, tools := bytes.Contains(line, []byte(`"usage"`)), bytes.Contains(line, []byte(`"tool_`))
	if !usage && !tools {
		return // a line of text only
	}
	var m struct {
		Type      string `json:"type"`
		Timestamp string `json:"timestamp"`
		Message   struct {
			Usage *struct {
				Input       int64 `json:"input_tokens"`
				CacheCreate int64 `json:"cache_creation_input_tokens"`
				CacheRead   int64 `json:"cache_read_input_tokens"`
				Output      int64 `json:"output_tokens"`
			} `json:"usage"`
			Content json.RawMessage `json:"content"`
		} `json:"message"`
	}
	if json.Unmarshal(line, &m) != nil {
		return
	}
	if tools {
		a.files.line(m.Type, m.Timestamp, m.Message.Content)
	}
	if m.Type != "assistant" || m.Message.Usage == nil {
		return
	}
	u := m.Message.Usage
	if n := u.Input + u.CacheCreate + u.CacheRead + u.Output; n > 0 && u.Input >= 0 && u.CacheCreate >= 0 && u.CacheRead >= 0 && u.Output >= 0 {
		a.tokens = n
	}
}

// readLogs reads what the transcripts of the run's agents in its journal
// added since the last read: a running agent's when due (every
// agentStat), which also says when the run last did anything; and once
// more, at once, each agent's that ended, or every agent's once the
// run's snapshot is there or it ended without one (ending). dir is the
// run's folder in the session's.
func (r *run) readLogs(root *os.Root, dir string, due, ending bool) {
	if r.logs == nil {
		r.logs = map[string]*agentLog{}
	}
	for _, row := range r.j.rows {
		if !agentID.MatchString(row.AgentID) {
			continue
		}
		a := r.logs[row.AgentID]
		if a == nil {
			a = &agentLog{}
			r.logs[row.AgentID] = a
		}
		running := row.State == "running" && r.snap == nil && !ending
		if a.final || running && !due {
			continue
		}
		f, fi, err := regularfile.OpenIn(root, path.Join(dir, "agent-"+row.AgentID+".jsonl"), false)
		if err != nil {
			continue // not written yet
		}
		_ = a.readLog(f, fi) // what was read stands; the next read goes on
		_ = f.Close()
		a.worktreeOf(root, dir, row.AgentID, !running)
		if a.final = !running; a.final {
			a.files.done()
		}
		if running {
			r.active = latest(r.active, fi.ModTime())
		}
	}
}

// tokensSum is the tokens of the agents of rows read so far.
func (r *run) tokensSum(rows []journalRow) int64 {
	var n int64
	for _, row := range rows {
		if a := r.logs[row.AgentID]; a != nil {
			n += a.tokens
		}
	}
	return n
}
