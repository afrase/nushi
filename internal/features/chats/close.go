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
// time each chat opens (model.ChatRecord.Throwaway). What the service started
// on its own ends first (its ctx, and its loops are waited for), and what a
// request left running (later) is waited for last: nothing writes the
// chats' records once Close has returned.
func (s *Service) Close() {
	s.cancel()
	s.loops.Wait()
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
	s.work.Wait() // cancelled with ctx; none begins once closing is set (later)
}

// later runs f on its own, as work Close waits for, unless Close has begun:
// then it doesn't run (false), and what it would have done waits for the
// next start (what it would have deleted stays in the chat's record:
// model.ChatRecord.Throwaway). It takes s.mu, a leaf lock: it may be
// called under a chat's lock, and nothing takes a chat's lock under s.mu.
func (s *Service) later(f func()) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closing {
		return false
	}
	s.work.Go(f)
	return true
}

// ending says the service's life is ending (Close cancels its ctx first):
// an agent Close killed didn't quit, and a reopen it cut short didn't
// fail, so neither says so in the chat.
func (s *Service) ending() bool { return s.ctx.Err() != nil }

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
		if s.closing {
			s.mu.Unlock()
			_ = agent.Close() // its process is gone either way
			return nil, errClosing
		}
		s.live[agent] = true
		s.mu.Unlock()
		go func() {
			<-agent.Done()
			s.mu.Lock()
			delete(s.live, agent)
			s.mu.Unlock()
			s.dropAgent(agent)
		}()
		s.recordAgent(agent) // a process listing and a file write: outside the lock
		return agent, nil
	}
}

var errClosing = errors.New("the daemon is stopping")
