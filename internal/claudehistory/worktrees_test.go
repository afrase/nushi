package claudehistory

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/afrase/claude-acp-go/claudeagent/sessions"
)

// Of a recorded session's three isolated subagents (testdata/claude-parity,
// subagent-worktree), two left work and keep their worktrees in their
// sidecars; the third left none, and its sidecar says nothing of it any more.
func TestSubagentWorktreesOfARecording(t *testing.T) {
	end := filepath.Join("..", "features", "chats", "testdata", "claude-parity", "subagent-worktree", "history", "end")
	transcripts, err := filepath.Glob(filepath.Join(end, "*.jsonl"))
	if err != nil || len(transcripts) != 1 {
		t.Fatalf("the recording's session: %v, %v", transcripts, err)
	}
	id := strings.TrimSuffix(filepath.Base(transcripts[0]), ".jsonl")
	config, folder := t.TempDir(), t.TempDir()
	project := sessions.Store{ConfigDir: config}.ProjectDir(folder)
	if err := os.MkdirAll(filepath.Dir(project), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.CopyFS(project, os.DirFS(end)); err != nil {
		t.Fatal(err)
	}
	got := Local{Projects: filepath.Join(config, "projects")}.SubagentWorktrees(id, folder)
	if len(got) != 2 {
		t.Fatalf("worktrees: %v", got)
	}
	name := regexp.MustCompile(`/work/\.claude/worktrees/agent-\w+$`)
	for call, path := range got {
		if !strings.HasPrefix(call, "toolu_") || !name.MatchString(path) {
			t.Errorf("%q: %q", call, path)
		}
	}
	metas, err := filepath.Glob(filepath.Join(end, id, "subagents", "*.meta.json"))
	if err != nil || len(metas) != 3 {
		t.Fatalf("sidecars: %v, %v", metas, err)
	}
	removed := 0
	for _, f := range metas {
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		var m struct {
			Removed bool `json:"worktreeCleanlyRemoved"`
		}
		if err := json.Unmarshal(b, &m); err != nil {
			t.Fatal(err)
		}
		if m.Removed {
			removed++
		}
	}
	if removed != 1 {
		t.Errorf("%d sidecars say their worktree went", removed)
	}
}

func TestSubagentWorktreesOfNoSession(t *testing.T) {
	if got := (Local{Projects: filepath.Join(t.TempDir(), "projects")}).SubagentWorktrees("none", t.TempDir()); len(got) != 0 {
		t.Errorf("worktrees: %v", got)
	}
}
