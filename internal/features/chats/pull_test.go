package chats

import (
	"fmt"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func pullLink(n int, branch string) model.ChatGitHub {
	return model.ChatGitHub{Host: "github.com", Repo: "a/b", Number: n, Pull: true, ID: fmt.Sprint("PR_", n), Branch: branch}
}

func numbers(pulls []model.ChatGitHub) []int {
	out := []int{}
	for _, p := range pulls {
		out = append(out, p.Number)
	}
	return out
}

// TestLinkPull (ADR 0117): a found pull request is added; one linked by
// hand takes the primary's place, or is added; unlinking one forgets it,
// and it isn't found again; a chat started from a pull request keeps it
// first until unlinked; a found one goes when the folder leaves its
// branch; Pull is the primary, for a release before Pulls.
func TestLinkPull(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	record := func() model.ChatRecord {
		s, err := svc.Session(c.id)
		testcheck.NoErr(t, err)
		return s
	}
	all := func() string { return fmt.Sprint(numbers(record().AllPulls())) }
	link := func(p model.ChatGitHub) { testcheck.NoErr(t, svc.LinkPull(c.id, &p)) }
	link(pullLink(7, "sub"))
	link(pullLink(7, "sub"))
	testcheck.NoErr(t, svc.AddPull(c.id, pullLink(8, "")))
	if got := all(); got != "[7 8]" {
		t.Fatalf("found, then added: %s", got)
	}
	link(pullLink(9, "")) // by hand, in the primary's place
	if r := record(); fmt.Sprint(numbers(r.AllPulls())) != "[9 8]" || r.Pull == nil || r.Pull.Number != 9 {
		t.Fatalf("linked by hand: %+v", r)
	}
	testcheck.NoErr(t, svc.UnlinkPull(c.id, pullLink(8, "")))
	link(pullLink(8, "sub"))
	if got := all(); got != "[9]" {
		t.Fatalf("found again once unlinked: %s", got)
	}
	testcheck.NoErr(t, svc.AddPull(c.id, pullLink(8, ""))) // by hand, it comes back
	link(pullLink(10, "sub"))
	svc.DropFoundPull(c.id, "sub")
	if got := all(); got != "[9 8 10]" {
		t.Fatalf("on its branch: %s", got)
	}
	svc.DropFoundPull(c.id, "main")
	if got := all(); got != "[9 8]" {
		t.Fatalf("its branch left: %s", got)
	}
	testcheck.NoErr(t, svc.LinkPull(c.id, nil))
	if r := record(); fmt.Sprint(numbers(r.AllPulls())) != "[8]" || r.NoPull != 9 {
		t.Fatalf("the primary unlinked: %+v", r)
	}
	c.mu.Lock()
	c.saveLocked(func(s *model.ChatRecord) { p := pullLink(3, ""); s.GitHub = &p })
	c.mu.Unlock()
	link(pullLink(3, "sub"))
	if got := all(); got != "[3 8]" {
		t.Fatalf("started from one: %s", got)
	}
	testcheck.NoErr(t, svc.UnlinkPull(c.id, pullLink(3, "")))
	if r := record(); r.GitHub != nil || fmt.Sprint(numbers(r.AllPulls())) != "[8]" {
		t.Fatalf("unlinked: %+v", r)
	}
	if err := svc.UnlinkPull(c.id, pullLink(99, "")); err == nil {
		t.Fatal("unlinked one it hasn't")
	}
}

// TestPullsAtMost: a chat holds 10 pull requests; one more by hand is
// refused, one more found is left out.
func TestPullsAtMost(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	for n := 1; n <= model.MaxPulls; n++ {
		testcheck.NoErr(t, svc.AddPull(c.id, pullLink(n, "")))
	}
	if err := svc.AddPull(c.id, pullLink(11, "")); err == nil {
		t.Fatal("an eleventh by hand")
	}
	p := pullLink(12, "sub")
	testcheck.NoErr(t, svc.LinkPull(c.id, &p))
	if s, _ := svc.Session(c.id); len(s.AllPulls()) != model.MaxPulls {
		t.Fatalf("%d", len(s.AllPulls()))
	}
}

// TestOldRecordsPull: a record written before Pulls takes Pull as its
// first.
func TestOldRecordsPull(t *testing.T) {
	p := pullLink(4, "sub")
	r := model.ChatRecord{Pull: &p}
	if got := numbers(r.AllPulls()); fmt.Sprint(got) != "[4]" || r.PullLink().Number != 4 {
		t.Fatalf("%v", got)
	}
}

// TestOpenedPull: a tool call that ran gh pr create, or a
// create_pull_request tool, links the first pull request address on a
// known host in its output as it completes, with the call's id; a link
// merely mentioned, another host's, or one unlinked isn't; it stays when
// the branch changes.
func TestOpenedPull(t *testing.T) {
	known := func(h string) bool { return h == "github.com" }
	bash := model.Item{ID: "t1", Kind: model.ToolCall, Status: "completed", Input: `{"command": "gh pr create --fill"}`,
		Text: "See https://evil.example/a/b/pull/1 and https://github.com/a/b/pull/12\nhttps://github.com/a/b/pull/13"}
	p, ok := openedPull(bash, known)
	if !ok || p.Number != 12 || p.Repo != "a/b" || p.Host != "github.com" || !p.Opened {
		t.Fatalf("%+v %v", p, ok)
	}
	mcp := model.Item{ID: "t2", Kind: model.ToolCall, Status: "completed", Tool: "mcp__github__create_pull_request",
		RawOutput: `{"html_url": "https://github.com/a/b/pull/5"}`}
	if p, ok := openedPull(mcp, known); !ok || p.Number != 5 {
		t.Fatalf("%+v %v", p, ok)
	}
	for _, it := range []model.Item{
		{Kind: model.ToolCall, Status: "completed", Input: `{"command": "gh pr view 3"}`, Text: "https://github.com/a/b/pull/3"},
		{Kind: model.ToolCall, Status: "failed", Input: `{"command": "gh pr create"}`, Text: "https://github.com/a/b/pull/3"},
		{Kind: model.AgentMessage, Status: "completed", Text: "gh pr create made https://github.com/a/b/pull/3"},
		{Kind: model.ToolCall, Status: "completed", Input: `{"command": "gh pr create"}`, Text: "https://evil.example/a/b/pull/3"},
	} {
		if p, ok := openedPull(it, known); ok {
			t.Fatalf("linked %+v from %+v", p, it)
		}
	}

	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.gitHubHost = known
	c.mu.Lock()
	c.openedPullLocked(bash)
	c.mu.Unlock()
	s, _ := svc.Session(c.id)
	if all := s.AllPulls(); len(all) != 1 || !all[0].Opened || all[0].ID != "" {
		t.Fatalf("%+v", all)
	}
	found := pullLink(12, "sub")
	testcheck.NoErr(t, svc.LinkPull(c.id, &found))
	svc.DropFoundPull(c.id, "main")
	s, _ = svc.Session(c.id)
	if all := s.AllPulls(); len(all) != 1 || all[0].ID != "PR_12" || !all[0].Opened || all[0].Branch != "" {
		t.Fatalf("found by its branch, then the branch changed: %+v", all)
	}
	testcheck.NoErr(t, svc.UnlinkPull(c.id, s.AllPulls()[0]))
	c.mu.Lock()
	c.openedPullLocked(bash)
	c.mu.Unlock()
	if s, _ := svc.Session(c.id); len(s.AllPulls()) != 0 {
		t.Fatalf("opened again once unlinked: %+v", s.AllPulls())
	}
}
