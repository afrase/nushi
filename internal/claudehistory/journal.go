package claudehistory

import (
	"bytes"
	"cmp"
	"encoding/json"
	"errors"
	"io"
)

// A workflow's journal (subagents/workflows/<run>/journal.jsonl) is read as
// it grows, from where the last read stopped; it is Claude's own, undocumented
// format (docs/facts/claude.md), so anything unexpected is passed over and
// counted, never an error.
const (
	maxJournalLine = 8 << 20  // a line longer is passed over: results can be large
	maxJournal     = 64 << 20 // the most of a journal read: thousands of agents fit
)

// errJournalTooBig says the journal grew past maxJournal: the rows read so
// far stand, and nothing more is read.
var errJournalTooBig = errors.New("workflow journal too big")

// journalRow is one agent of a workflow as its journal tells: State is
// "running" from its started line, "done" from its result, "failed", or
// "stopped" when the run it started in ended before it did (a resume
// follows).
type journalRow struct {
	Key, AgentID, Label, Phase, State string
}

// journal reads a workflow's journal incrementally (lines). Rows are in start order, found
// by their key (a failed line has an empty agentId). The journal is one
// for every launch of the same run id, as Claude's own reader takes it: a
// resume keeps the results it has and starts again only what had none.
// Claude 2.1.325 was read to append a resumed line (a launched one only
// for a hidden script's), which ends the rows still running, stopped with
// the launch before; 2.1.331 was seen to mark nothing of a plain resume
// (the workflow-resume recordings), so the launches are told apart by
// their snapshots instead (run.rows). One started again runs again.
type journal struct {
	lines
	rows  []journalRow
	byKey map[string]int
}

// read reads what was added to the journal since the last read; a journal
// smaller than what was read is read again from its start (it was
// rewritten).
func (j *journal) read(r io.ReaderAt, size int64) error {
	if size < j.off {
		*j = journal{}
	}
	if err := j.lines.read(r, min(size, maxJournal), maxJournalLine, j.line); err != nil {
		return err
	}
	if size > maxJournal {
		return errJournalTooBig
	}
	return nil
}

// line applies one journal line; a line that isn't one of the known kinds,
// or not as expected, is passed over.
func (j *journal) line(line []byte) {
	line = bytes.TrimSpace(bytes.TrimPrefix(line, []byte("\xef\xbb\xbf")))
	if len(line) == 0 {
		return
	}
	var l struct {
		Type    string `json:"type"`
		Key     string `json:"key"`
		AgentID string `json:"agentId"`
		Label   string `json:"label"`
		Phase   string `json:"phase"`
	}
	if json.Unmarshal(line, &l) != nil {
		j.skipped++
		return
	}
	if j.byKey == nil {
		j.byKey = map[string]int{}
	}
	i, known := j.byKey[l.Key]
	switch {
	case l.Type == "launched" || l.Type == "resumed":
		for i := range j.rows {
			if j.rows[i].State == "running" {
				j.rows[i].State = "stopped"
			}
		}
	case l.Key == "":
		j.skipped++
	case l.Type == "started" && known:
		r := &j.rows[i]
		r.AgentID, r.State = cmp.Or(l.AgentID, r.AgentID), "running"
		r.Label, r.Phase = cmp.Or(l.Label, r.Label), cmp.Or(l.Phase, r.Phase)
	case l.Type == "started":
		j.byKey[l.Key] = len(j.rows)
		j.rows = append(j.rows, journalRow{Key: l.Key, AgentID: l.AgentID, Label: l.Label, Phase: l.Phase, State: "running"})
	case (l.Type == "result" || l.Type == "failed") && known:
		r := &j.rows[i]
		r.AgentID, r.State = cmp.Or(r.AgentID, l.AgentID), map[string]string{"result": "done", "failed": "failed"}[l.Type]
	default:
		j.skipped++
	}
}
