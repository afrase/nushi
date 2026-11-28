package claudehistory

import (
	"encoding/json"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/regularfile"
)

// The worktrees Claude gave a workflow's subagents (a script's
// isolation: 'worktree'): a subagent's sidecar, agent-<id>.meta.json
// beside its transcript, names its worktree (worktreePath, with
// spawnedWithWorktree true) from early in its life, and keeps naming it
// after the worktree is gone (docs/facts/claude.md, "A workflow's helpers
// and worktrees"). A chat's related worktrees take them as Claude's word
// (ADR 0081). The path is Claude's text, never a file Nushi opens here.

// maxMeta is the most of a sidecar read, as for a chat's subagents'
// (claude-acp-go's sessions): Claude's are a few hundred bytes.
const maxMeta = 64 << 10

// worktreeOf is the worktree a sidecar names, read when its subagent is
// first read and again while it names none, until the subagent ended
// (final: the last read): a regular file, maxMeta at most, in the run's
// folder dir of root.
func (a *agentLog) worktreeOf(root *os.Root, dir, id string, final bool) {
	if a.metaRead {
		return
	}
	a.metaRead = final
	data, err := regularfile.ReadIn(root, path.Join(dir, "agent-"+id+".meta.json"), maxMeta)
	if err != nil {
		return // not written yet, or no sidecar's
	}
	var meta struct {
		WorktreePath string `json:"worktreePath"`
		Spawned      bool   `json:"spawnedWithWorktree"`
	}
	if json.Unmarshal(data, &meta) != nil || !meta.Spawned {
		return
	}
	p, ok := worktreePath(meta.WorktreePath)
	if !ok {
		return
	}
	a.worktree, a.metaRead = p, true
}

// worktreePath is p as a worktree's path: absolute, cleaned, maxPath bytes
// at most, with no NUL and no line break (LF, CR, NEL, U+2028, U+2029), as
// git lists a worktree no other way. (JSON's decoding already made it
// valid text.)
func worktreePath(p string) (string, bool) {
	if len(p) > maxPath || strings.ContainsAny(p, "\x00\n\r\u0085  ") || !filepath.IsAbs(p) {
		return "", false
	}
	return filepath.Clean(p), true
}

// begin takes the time of a transcript's first line (stamp), else the
// transcript's time at this read: when its subagent began.
func (a *agentLog) begin(stamp string) {
	a.begun = true
	when, err := time.Parse(time.RFC3339Nano, stamp)
	if err != nil {
		when = a.files.mod
	}
	a.since = when
}

// worktrees are the worktrees Claude gave the agents of rows, in the
// journal's order, each once (at its first agent's start),
// WorkflowWorktrees at most.
func (r *run) worktrees(rows []journalRow) []model.WorkflowWorktree {
	var out []model.WorkflowWorktree
	seen := map[string]bool{}
	for _, row := range rows {
		a := r.logs[row.AgentID]
		if a == nil || a.worktree == "" || seen[a.worktree] {
			continue
		}
		if len(out) >= model.WorkflowWorktrees {
			break
		}
		seen[a.worktree] = true
		out = append(out, model.WorkflowWorktree{Path: a.worktree, Since: a.since})
	}
	return out
}
