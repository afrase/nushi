package transcripts

import (
	"runtime"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// Heads gives every item as the copy has it now, in order, with only what
// finds a page (its images by hash, no bytes); Pick reads those asked for
// whole, in the copy's order, and sees what was written since.
func TestHeadsAndPick(t *testing.T) {
	s, _ := open(t)
	img := model.Image{MimeType: "image/png", Data: []byte("png bytes")}
	step := model.Item{ID: "s1", Kind: model.ToolCall, Status: "completed", Parent: "sa", WorktreePath: "/wt", Text: "step", Images: []model.Image{img},
		Started: time.UnixMilli(1000).UTC(), Ended: time.UnixMilli(2000).UTC(),
		Workflow: &model.Workflow{RunID: "wf_1", Name: "audit", Written: []model.WrittenFile{{Path: "a.md", Changed: time.UnixMilli(1500).UTC()}}}}
	add(t, s, "C", "", msg("a", "A"), msg("b", "B"), step, msg("c", "C"), msg("d", "D"))
	add(t, s, "C", "a", msg("b", "B2")) // written again, in place
	testcheck.NoErr(t, s.Drop("C", "c"))
	heads, err := s.Heads("C")
	testcheck.NoErr(t, err)
	got := make([]string, len(heads))
	for i, h := range heads {
		got[i] = h.ID + "/" + h.Text
	}
	if strings.Join(got, " ") != "a/ b/ s1/ d/" {
		t.Fatalf("heads %v", got)
	}
	if h := heads[2]; h.Parent != "sa" || h.WorktreePath != "/wt" || len(h.Images) != 1 || h.Images[0].Data != nil || h.Images[0].Hash == "" || h.Images[0].MimeType != "image/png" {
		t.Errorf("a step's head %+v", h)
	}
	// What writtenBy reads of a workflow's call, and no more of its run.
	if h := heads[2]; !h.Ended.Equal(step.Ended) || !h.Started.Equal(step.Started) || h.Workflow == nil || h.Workflow.Name != "" || h.Workflow.RunID != "wf_1" ||
		len(h.Workflow.Written) != 1 || h.Workflow.Written[0] != step.Workflow.Written[0] {
		t.Errorf("a workflow call's head: %+v, %+v", h, h.Workflow)
	}
	picked, err := s.Pick("C", []string{"d", "s1", "b", "c", "none"})
	testcheck.NoErr(t, err)
	if ids(picked) != "b=B2 s1=step d=D" || string(picked[1].Images[0].Data) != "png bytes" {
		t.Fatalf("picked %s %+v", ids(picked), picked[1].Images)
	}
	add(t, s, "C", "s1", msg("d", "D2"))
	if picked, _ := s.Pick("C", []string{"d"}); ids(picked) != "d=D2" {
		t.Errorf("after a write, picked %s", ids(picked))
	}
	if heads, err := s.Heads("NONE"); heads != nil || err != nil {
		t.Errorf("a chat without a copy has heads %v, %v", heads, err)
	}
}

// A workflow call's head carries what a chat's related worktrees read of
// its run (its id, folder, written files and worktrees) when it wrote a
// file or had a worktree, and nothing of a run that had neither.
func TestHeadsOfWorkflows(t *testing.T) {
	s, _ := open(t)
	since := time.UnixMilli(1000).UTC()
	wt := model.WorkflowWorktree{Path: "/repo/.claude/worktrees/wf_1-1", Since: since}
	call := func(id string, w model.Workflow) model.Item {
		return model.Item{ID: id, Kind: model.ToolCall, Status: "completed", Workflow: &w}
	}
	add(t, s, "C", "",
		call("trees", model.Workflow{RunID: "wf_1", Name: "isolated", Folder: "/repo", Worktrees: []model.WorkflowWorktree{wt}}),
		call("none", model.Workflow{RunID: "wf_2", Name: "read only", Folder: "/repo"}))
	heads, err := s.Heads("C")
	testcheck.NoErr(t, err)
	if h := heads[0].Workflow; h == nil || h.RunID != "wf_1" || h.Folder != "/repo" || h.Name != "" || len(h.Worktrees) != 1 || h.Worktrees[0] != wt {
		t.Errorf("a run with a worktree: %+v", h)
	}
	if h := heads[1].Workflow; h != nil {
		t.Errorf("a run with neither: %+v", h)
	}
}

// A page of a long copy costs its heads once and then its own items: its
// size isn't read again for each page, nor decoded whole.
func TestPagesReadLittle(t *testing.T) {
	s, _ := open(t)
	text := strings.Repeat("output of a tool call\n", 300) // about 6.6 KB
	items := make([]model.Item, 4500)
	afters := make([]string, len(items))
	for i := range items {
		items[i] = model.Item{ID: "item-" + strconv.Itoa(i), Kind: model.ToolCall, Status: "completed", Text: text}
	}
	for i := 1; i < len(items); i++ {
		afters[i] = items[i-1].ID
	}
	testcheck.NoErr(t, s.Append("BIG", items, afters))
	page := func(end int) {
		heads, err := s.Heads("BIG")
		testcheck.NoErr(t, err)
		var want []string
		for _, h := range heads[end-200 : end] {
			want = append(want, h.ID)
		}
		got, err := s.Pick("BIG", want)
		testcheck.NoErr(t, err)
		if len(got) != 200 || got[0].Text != text || got[0].ID != want[0] {
			t.Fatalf("page before %d: %d items", end, len(got))
		}
	}
	page(4500) // the index, made once
	var before, after runtime.MemStats
	runtime.ReadMemStats(&before)
	for end := 4300; end >= 300; end -= 200 {
		page(end)
	}
	runtime.ReadMemStats(&after)
	// About 6 MB a page (7 with -race): the page's 1.3 MB of text and
	// every item's head handed out. Read allocates about 66 MB for the
	// copy, and the index's pass about as much as reading only its heads.
	if alloc := (after.TotalAlloc - before.TotalAlloc) / 20; alloc > 12<<20 {
		t.Errorf("a page allocated %d MB of a 30 MB copy", alloc>>20)
	}
	if s.indexes["BIG"] == nil || !slices.Equal(s.indexed, []string{"BIG"}) {
		t.Errorf("index kept for %v", s.indexed)
	}
}
