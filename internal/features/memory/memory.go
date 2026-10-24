// Package memory says how much memory Nushi takes: the daemon, each chat's
// agent, and the app, as footprint (internal/footprint) reads it.
package memory

import (
	"os"

	"github.com/afrase/nushi/internal/footprint"
)

// Chats says whose agents run: each chat's agent process, by chat id.
type Chats interface {
	AgentPids() map[string]int
}

// Report is what each part takes, in bytes.
type Report struct {
	Daemon uint64            // nushid itself
	App    uint64            // the app that asked, with what it started
	Other  uint64            // the daemon's other processes: terminals, agents no chat holds
	Chats  map[string]uint64 // each chat's agent, with what it started, by chat id
}

type Service struct{ chats Chats }

func New(chats Chats) *Service { return &Service{chats} }

// Report reads how much each part takes now; app is the asking app's
// process, or 0. It reads every process once (a few milliseconds).
func (s *Service) Report(app int) (Report, error) {
	procs, err := footprint.Snapshot()
	if err != nil {
		return Report{}, err
	}
	chats := map[int]string{}
	for id, pid := range s.chats.AgentPids() {
		chats[pid] = id
	}
	self := os.Getpid()
	r := Report{Daemon: footprint.Of(self), Chats: map[string]uint64{}}
	if app > 0 {
		r.App = procs.Tree(app)
	}
	for _, child := range procs.Children(self) {
		if id, ok := chats[child]; ok {
			r.Chats[id] = procs.Tree(child)
		} else {
			r.Other += procs.Tree(child)
		}
	}
	return r, nil
}
