package pitest

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync/atomic"
	"time"
)

// load opens a session file.
func (p *Program) load(file string) {
	b, err := os.ReadFile(file) //nolint:gosec // the fake's session file in a test's folder
	if err != nil {
		return
	}
	p.file = file
	for i, line := range strings.Split(strings.TrimSpace(string(b)), "\n") {
		var e map[string]any
		_ = json.Unmarshal([]byte(line), &e)
		if i == 0 {
			p.id, p.cwd = e["id"].(string), e["cwd"].(string)
			continue
		}
		p.entries = append(p.entries, e)
		p.leaf = e["id"]
		if m, _ := e["message"].(map[string]any); m != nil && m["role"] == "system" {
			p.prompted = true
		}
	}
}

var clock, greets atomic.Int64

// stamp is a message's time: milliseconds, unique.
func stamp() int64 {
	clock.CompareAndSwap(0, time.Now().UnixMilli())
	return clock.Add(1)
}

// append adds a message to the session's branch, and writes the file.
func (p *Program) append(msg map[string]any) {
	p.add(map[string]any{"type": "message", "message": msg})
}

// add adds an entry to the session's branch, and writes the file.
func (p *Program) add(entry map[string]any) {
	id := fmt.Sprintf("e%d", len(p.entries)+1)
	entry["id"], entry["parentId"] = id, p.leaf
	b, _ := json.Marshal(entry)
	var e map[string]any
	_ = json.Unmarshal(b, &e) // as read from the file
	p.entries = append(p.entries, e)
	p.leaf = id
	p.save()
}

func (p *Program) save() {
	if !slices.ContainsFunc(p.entries, func(e map[string]any) bool { // a session is written with its first message
		m, _ := e["message"].(map[string]any)
		return m != nil && m["role"] != "system"
	}) {
		return
	}
	h := map[string]any{"type": "session", "version": 3, "id": p.id, "cwd": p.cwd}
	if p.parent != "" {
		h["parentSession"] = p.parent
	}
	var b strings.Builder
	for _, v := range append([]map[string]any{h}, p.entries...) {
		line, _ := json.Marshal(v)
		b.Write(append(line, '\n'))
	}
	_ = os.WriteFile(p.file, []byte(b.String()), 0o600)
}

// fork switches to a new session: the branch up to before the user's
// message entryId (fork), or all of it (clone).
func (p *Program) fork(cmd map[string]any) {
	var keep []map[string]any
	text := ""
	for _, e := range p.entries {
		if e["id"] == cmd["entryId"] {
			m := e["message"].(map[string]any)
			text = m["content"].([]any)[0].(map[string]any)["text"].(string)
			break
		}
		keep = append(keep, e)
	}
	p.parent, p.entries, p.leaf = p.file, keep, nil
	if len(keep) > 0 {
		p.leaf = keep[len(keep)-1]["id"]
	}
	p.id = p.st.newID()
	p.file = filepath.Join(p.st.Sessions, p.id+".jsonl")
	p.save()
	data := map[string]any{"cancelled": false}
	if cmd["type"] == "fork" {
		data["text"] = text
	}
	p.greet("fork") // the new session's extensions start
	p.respond(cmd, data, "")
	if p.st.Shape == PiG053 { // 0.5.3 started them once more after its answer
		p.greet("fork")
	}
}

// compact summarizes the session: "Summary: <instructions>"; with nothing
// to summarize it fails as Pi does, and "slow" waits for an abort.
func (p *Program) compact(cmd map[string]any) {
	p.emit(map[string]any{"type": "compaction_start", "reason": "manual"})
	p.mu.Lock()
	defer p.mu.Unlock()
	instructions, _ := cmd["customInstructions"].(string)
	if len(p.entries) < 2 {
		p.emit(map[string]any{"type": "compaction_end", "reason": "manual", "aborted": false, "willRetry": false,
			"errorMessage": "Compaction failed: Nothing to compact (session too small)"})
		p.respond(cmd, nil, "Nothing to compact (session too small)")
		return
	}
	if instructions == "slow" {
		stop := make(chan struct{})
		p.compacting = stop
		p.mu.Unlock()
		p.st.waiting("/compact " + instructions)
		<-stop
		p.mu.Lock()
		p.emit(map[string]any{"type": "compaction_end", "reason": "manual", "aborted": true, "willRetry": false})
		p.respond(cmd, nil, "Compaction cancelled")
		return
	}
	result := map[string]any{"summary": "Summary: " + instructions, "firstKeptEntryId": p.leaf, "tokensBefore": 100 * len(p.entries), "estimatedTokensAfter": 42}
	p.add(map[string]any{"type": "compaction", "summary": result["summary"], "firstKeptEntryId": p.leaf, "tokensBefore": result["tokensBefore"]})
	p.emit(map[string]any{"type": "compaction_end", "reason": "manual", "result": result, "aborted": false, "willRetry": false})
	p.respond(cmd, result, "")
}
