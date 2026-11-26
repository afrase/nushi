package claudehistory

import (
	"bytes"
	"encoding/json"
	"io"
	"os"
	"path"

	"github.com/afrase/nushi/internal/regularfile"
)

// A workflow's tokens while it runs (#103): its agents write nothing to
// claude's output and aren't a chat's turns (ADR 0136), so they are read
// from the agents' own transcripts, as claude counts a subagent's
// totalTokens: its last message's input, cache and output tokens
// (docs/facts/claude.md). The run's total is the sum over its agents.
// Once the run ended its snapshot's own total stands.

// agentTokens is what was read of one agent's transcript for its tokens:
// its last message's, read as the transcript grows (lines). final says it
// was read after its agent ended: nothing more comes.
type agentTokens struct {
	lines
	tokens int64
	final  bool
}

// read reads what the transcript (f, of size bytes) added since the last.
func (a *agentTokens) read(f io.ReaderAt, size int64) error {
	if size < a.off { // rewritten
		*a = agentTokens{}
	}
	return a.lines.read(f, min(size, maxAgentLog), maxStepLine, a.line)
}

// line takes one line of the transcript: an assistant message's usage,
// when it has any, is the agent's tokens now.
func (a *agentTokens) line(line []byte) {
	if !bytes.Contains(line, []byte(`"usage"`)) {
		return // a user's line (a tool's result), or one without usage
	}
	var m struct {
		Type    string `json:"type"`
		Message struct {
			Usage *struct {
				Input       int64 `json:"input_tokens"`
				CacheCreate int64 `json:"cache_creation_input_tokens"`
				CacheRead   int64 `json:"cache_read_input_tokens"`
				Output      int64 `json:"output_tokens"`
			} `json:"usage"`
		} `json:"message"`
	}
	if json.Unmarshal(line, &m) != nil || m.Type != "assistant" || m.Message.Usage == nil {
		return
	}
	u := m.Message.Usage
	if n := u.Input + u.CacheCreate + u.CacheRead + u.Output; n > 0 && u.Input >= 0 && u.CacheCreate >= 0 && u.CacheRead >= 0 && u.Output >= 0 {
		a.tokens = n
	}
}

// readTokens reads what the transcripts of the run's agents in its
// journal added since the last read: each agent's while it runs, and once
// more after it ended. dir is the run's folder in the session's.
func (r *run) readTokens(root *os.Root, dir string) {
	if r.tokens == nil {
		r.tokens = map[string]*agentTokens{}
	}
	for _, row := range r.j.rows {
		if !agentID.MatchString(row.AgentID) {
			continue
		}
		a := r.tokens[row.AgentID]
		if a == nil {
			a = &agentTokens{}
			r.tokens[row.AgentID] = a
		}
		running := row.State == "running"
		if a.final && !running {
			continue
		}
		f, fi, err := regularfile.OpenIn(root, path.Join(dir, "agent-"+row.AgentID+".jsonl"), false)
		if err != nil {
			continue // not written yet
		}
		_ = a.read(f, fi.Size()) // what was read stands; the next read goes on
		_ = f.Close()
		a.final = !running
	}
}

// tokensSum is the tokens of the agents of rows read so far.
func (r *run) tokensSum(rows []journalRow) int64 {
	var n int64
	for _, row := range rows {
		if a := r.tokens[row.AgentID]; a != nil {
			n += a.tokens
		}
	}
	return n
}
