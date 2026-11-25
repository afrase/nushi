package claude

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// recordedWorksIn is what WorksIn reads from every tool call update of a
// parity recording (chats' testdata/claude-parity), in order: the tool
// and what it said, with the run's folder cut from each path.
func recordedWorksIn(t *testing.T, scenario string) []string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("..", "features", "chats", "testdata", "claude-parity", scenario, "acp.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for l := range bytes.Lines(b) {
		var line struct {
			Dir string `json:"dir"`
			Msg struct {
				Method string `json:"method"`
				Params struct {
					Update struct {
						Kind string         `json:"sessionUpdate"`
						Meta map[string]any `json:"_meta"`
					} `json:"update"`
				} `json:"params"`
			} `json:"msg"`
		}
		if err := json.Unmarshal(l, &line); err != nil {
			t.Fatal(err)
		}
		u := line.Msg.Params.Update
		if line.Dir != "out" || line.Msg.Method != "session/update" || (u.Kind != "tool_call" && u.Kind != "tool_call_update") {
			continue
		}
		to, ok := Harness{}.WorksIn(u.Meta)
		if !ok {
			continue
		}
		if _, rel, cut := strings.Cut(to.Path, "/work/"); cut {
			to.Path = rel
		}
		got = append(got, claudeCode(u.Meta, "toolName")+" "+to.Path)
	}
	return got
}

// WorksIn reads Claude's recorded EnterWorktree and ExitWorktree results:
// each completed call once, by path or by name, and nothing from a failed
// call (a second EnterWorktree, an ExitWorktree refused or a no-op, as in
// a fork into the worktree), a cd in Bash or a subagent's worktree
// (docs/facts/claude.md).
func TestWorksInRecorded(t *testing.T) {
	for scenario, want := range map[string][]string{
		"worktree-enter-path": {"EnterWorktree .worktrees/side", "ExitWorktree "},
		"worktree-enter-name": {"EnterWorktree .claude/worktrees/made", "ExitWorktree ", "EnterWorktree .claude/worktrees/stays"},
		"worktree-second":     {"EnterWorktree .claude/worktrees/first", "ExitWorktree "},
		"worktree-gone":       {"EnterWorktree .worktrees/side", "ExitWorktree "},
		"worktree-fork-into":  {"EnterWorktree .claude/worktrees/into"},
		"worktree-bash-cd":    nil,
		"subagent-worktree":   nil,
	} {
		got := recordedWorksIn(t, scenario)
		if strings.Join(got, "\n") != strings.Join(want, "\n") {
			t.Errorf("%s: %q, want %q", scenario, got, want)
		}
	}
}

func TestWorksIn(t *testing.T) {
	meta := func(tool string, resp map[string]any) map[string]any {
		return map[string]any{"claudeCode": map[string]any{"toolName": tool, "toolResponse": resp}}
	}
	for _, tc := range []struct {
		meta map[string]any
		want model.AgentWorktree
		ok   bool
	}{
		{meta("EnterWorktree", map[string]any{"worktreePath": "/r/wt", "worktreeBranch": "b"}), model.AgentWorktree{Path: "/r/wt"}, true},
		{meta("EnterWorktree", map[string]any{"worktreeBranch": "b"}), model.AgentWorktree{}, false},
		{meta("EnterWorktree", map[string]any{"worktreePath": 3}), model.AgentWorktree{}, false},
		{meta("ExitWorktree", map[string]any{"action": "keep"}), model.AgentWorktree{}, true},
		{meta("ExitWorktree", nil), model.AgentWorktree{}, false},
		{meta("Agent", map[string]any{"worktreePath": "/r/wt"}), model.AgentWorktree{}, false},
		{map[string]any{"claudeCode": map[string]any{"toolName": "EnterWorktree"}}, model.AgentWorktree{}, false},
		{nil, model.AgentWorktree{}, false},
	} {
		got, ok := Harness{}.WorksIn(tc.meta)
		if ok != tc.ok || got != tc.want {
			t.Errorf("%v: %+v %v, want %+v %v", tc.meta, got, ok, tc.want, tc.ok)
		}
	}
}
