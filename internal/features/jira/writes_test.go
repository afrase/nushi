package jira

import (
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// An agent's write is kept without the service's lock: while the store
// adds it, a list and the issue's writes still answer.
func TestAWriteBeingKeptHoldsUpNoList(t *testing.T) {
	s, _, _ := newService(t)
	if _, err := s.AddSite(t.Context(), "https://e.atlassian.net", "me@e.com", "good", time.Time{}); err != nil {
		t.Fatal(err)
	}
	m := s.store.(*memStore)
	adding, hold := make(chan struct{}), make(chan struct{})
	m.adding = func() {
		close(adding)
		<-hold
	}
	release := sync.OnceFunc(func() { close(hold) })
	t.Cleanup(release)
	kept := make(chan struct{})
	go func() {
		defer close(kept)
		s.wrote(model.JiraWrite{Site: "e.atlassian.net", Key: "A-1", Kind: "comment"})
	}()
	<-adding

	answered := make(chan struct{})
	go func() {
		defer close(answered)
		_, _ = s.List(t.Context(), "e.atlassian.net", Mine, "")
		_ = s.Writes("e.atlassian.net", "A-1")
	}()
	testcheck.Wait(t, "a list to answer while a write is kept", func() bool {
		select {
		case <-answered:
			return true
		default:
			return false
		}
	})

	release()
	<-kept
	if w := s.Writes("e.atlassian.net", "A-1"); len(w) != 1 || w[0].At.IsZero() {
		t.Errorf("kept %+v", w)
	}
}
