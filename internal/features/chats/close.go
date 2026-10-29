package chats

import (
	"errors"
	"log/slog"
	"maps"
	"slices"
	"sync"

	acp "github.com/afrase/acp-go/unstable"
)

// Close stops every chat's agent, all at once, as stop does: a running turn
// is cancelled and gets a few seconds to end, so the agent records how it
// ended. Their side chats are deleted from the agent's history the next
// time each chat opens (model.Session.Throwaway). What the service started
// on its own ends first (its ctx).
func (s *Service) Close() {
	s.cancel()
	s.mu.Lock()
	s.closing = true
	if s.idle != nil {
		s.idle.Stop()
	}
	open := slices.Collect(maps.Values(s.chats))
	s.mu.Unlock()
	var wg sync.WaitGroup
	for _, c := range open {
		if c.parent == nil { // a side chat shares its chat's agent
			wg.Go(func() { s.end(c) })
		}
	}
	wg.Wait()
	s.mu.Lock()
	left := slices.Collect(maps.Keys(s.live))
	s.mu.Unlock()
	for _, agent := range left {
		_ = agent.Close() // being opened: no turn of it to end
	}
}

// started wraps launch: once Close has begun, no agent starts, and the
// agents still running when it has ended the chats' (those a reopen or a
// move was opening meanwhile) are closed too.
func (s *Service) started(launch Launch) Launch {
	return func(h acp.Client, log *slog.Logger) (Agent, error) {
		s.mu.Lock()
		closing := s.closing
		s.mu.Unlock()
		if closing {
			return nil, errClosing
		}
		agent, err := launch(h, log)
		if err != nil {
			return nil, err
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		if s.closing {
			_ = agent.Close() // its process is gone either way
			return nil, errClosing
		}
		s.live[agent] = true
		go func() {
			<-agent.Done()
			s.mu.Lock()
			delete(s.live, agent)
			s.mu.Unlock()
		}()
		return agent, nil
	}
}

var errClosing = errors.New("the daemon is stopping")
