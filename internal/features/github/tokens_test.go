package github

import (
	"slices"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// heldStore is fakeStore whose first save of the token hosts waits for
// hold, saying so on saving.
type heldStore struct {
	*fakeStore
	mu     sync.Mutex
	saves  int
	saving chan struct{}
	hold   chan struct{}
}

func (s *heldStore) GitHubTokenHosts() ([]string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.Clone(s.hosts), nil
}

func (s *heldStore) SaveGitHubTokenHosts(h []string) error {
	s.mu.Lock()
	s.saves++
	first := s.saves == 1
	s.mu.Unlock()
	if first {
		close(s.saving)
		<-s.hold
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.hosts = h
	return nil
}

// Two tokens added at once are both kept: each change reads github.json
// and writes it back in one step, so neither writes over the other. The
// service's other calls don't wait for that write.
func TestTokensAddedAtOnceAreBothKept(t *testing.T) {
	w := newWorld(t)
	st := &heldStore{fakeStore: w.store, saving: make(chan struct{}), hold: make(chan struct{})}
	w.s.Store = st
	ctx := t.Context()
	release := sync.OnceFunc(func() { close(st.hold) })
	t.Cleanup(release)

	var adds sync.WaitGroup
	adds.Go(func() { _, _ = w.s.AddToken(ctx, "a.example.com", "ghp_a") })
	<-st.saving
	adds.Go(func() { _, _ = w.s.AddToken(ctx, "b.example.com", "ghp_b") })
	testcheck.Wait(t, "the second token in the keychain", func() bool {
		_, err := w.tokens.Get("b.example.com", false)
		return err == nil
	})

	other := make(chan struct{})
	go func() {
		_, _ = w.s.Hosts(ctx)
		close(other)
	}()
	testcheck.Wait(t, "Hosts to answer while github.json is written", func() bool {
		select {
		case <-other:
			return true
		default:
			return false
		}
	})

	release()
	adds.Wait()
	hosts, _ := st.GitHubTokenHosts()
	slices.Sort(hosts)
	if !slices.Equal(hosts, []string{"a.example.com", "b.example.com"}) {
		t.Errorf("github.json lists %v, want both hosts", hosts)
	}
}
