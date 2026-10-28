package chats

import (
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// TestLinkPull: a found pull request links; one linked by hand stays over
// a found one; unlinking forgets it, and that one isn't found again; a
// chat started from a pull request unlinks that one; a found one goes
// when the folder leaves its branch.
func TestLinkPull(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	pull := func() *model.ChatGitHub {
		s, err := svc.Session(c.id)
		noErr(t, err)
		return s.PullLink()
	}
	found := func(n int, branch string) *model.ChatGitHub {
		return &model.ChatGitHub{Host: "github.com", Repo: "a/b", Number: n, Pull: true, ID: "PR", Branch: branch}
	}
	noErr(t, svc.LinkPull(c.id, found(7, "sub")))
	if p := pull(); p == nil || p.Number != 7 || p.Branch != "sub" {
		t.Fatalf("found: %+v", p)
	}
	noErr(t, svc.LinkPull(c.id, found(8, "")))
	noErr(t, svc.LinkPull(c.id, found(7, "sub")))
	if p := pull(); p.Number != 8 {
		t.Fatalf("linked by hand, then found: %+v", p)
	}
	noErr(t, svc.LinkPull(c.id, nil))
	noErr(t, svc.LinkPull(c.id, found(8, "sub")))
	if p := pull(); p != nil {
		t.Fatalf("found again once unlinked: %+v", p)
	}
	noErr(t, svc.LinkPull(c.id, found(9, "sub")))
	svc.DropFoundPull(c.id, "sub")
	if p := pull(); p == nil || p.Number != 9 {
		t.Fatalf("another one found: %+v", p)
	}
	svc.DropFoundPull(c.id, "main")
	if p := pull(); p != nil {
		t.Fatalf("its branch left: %+v", p)
	}
	c.mu.Lock()
	c.saveLocked(func(s *model.Session) { s.GitHub = found(3, "") })
	c.mu.Unlock()
	noErr(t, svc.LinkPull(c.id, found(4, "sub")))
	if p := pull(); p.Number != 3 {
		t.Fatalf("started from one: %+v", p)
	}
	noErr(t, svc.LinkPull(c.id, nil))
	if s, _ := svc.Session(c.id); s.GitHub != nil || s.Pull != nil || s.NoPull != 3 {
		t.Fatalf("unlinked: %+v", s)
	}
}
