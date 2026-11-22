package store

import (
	"errors"
	"log/slog"
	"maps"
	"path/filepath"
	"time"
)

// settings are the daemon's own settings (settings.json). A key no field
// names is ignored as it is read, and gone once a change is written:
// claudeGoAgent, which ran Claude through the Go agent while the Node
// adapter was the default (ADR 0066).
type settings struct {
	SleepAfterMinutes *int  `json:"sleepAfterMinutes,omitempty"`
	DebugLog          bool  `json:"debugLog,omitempty"`
	KeepTranscripts   *bool `json:"keepTranscripts,omitempty"`
	TranscriptDays    int   `json:"transcriptDays,omitempty"`
	CheckUpdates      *bool `json:"checkUpdates,omitempty"`
	// GoAgents are the agents run through Nushi's Go agent, by name; one
	// that's off isn't kept.
	GoAgents map[string]bool `json:"goAgents,omitempty"`
	// CodexGoAgent is goAgents' "codex" as written before it was kept by
	// agent (ADR 0142), the key v0.52.0 reads: read into GoAgents, and
	// mirrored from it on every write so going back to v0.52.0 keeps the
	// choice (ADR 0108). The mirror goes after the v0.53.0 tag; the read
	// after v0.54.0, since a file is rewritten only when a setting changes.
	CodexGoAgent bool `json:"codexGoAgent,omitempty"`
}

// oldGoAgent is the agent settings.json's codexGoAgent was for.
const oldGoAgent = "codex"

// defaultSleepAfter is how long chats idle before they sleep, until the
// user picks another time.
const defaultSleepAfter = 30 * time.Minute

// settingsLocked is settings.json, read once and then kept (a hand edit
// while the daemon runs is seen at its next start); one that can't be
// read is as if empty, and one that doesn't parse counts for what it
// could read. Either way the read's error is kept for the next change.
func (s *Store) settingsLocked() settings {
	if s.set != nil {
		return *s.set
	}
	var set settings
	if _, err := readJSON(filepath.Join(s.dir, "settings.json"), &set); err != nil {
		slog.Warn("reading settings.json", "err", err)
		s.setErr = err
	}
	if set.CodexGoAgent { // the old key's read: delete after v0.54.0
		if _, ok := set.GoAgents[oldGoAgent]; !ok {
			if set.GoAgents == nil {
				set.GoAgents = map[string]bool{}
			}
			set.GoAgents[oldGoAgent] = true
		}
		set.CodexGoAgent = false
	}
	s.set = &set
	return set
}

// changeSettings applies change to settings.json, and keeps the result
// once it's written. A file that couldn't be read is never written over
// (clearForWrite): one that doesn't parse is set aside first, and one
// that can't be read at all is tried again, refusing the change if it
// still can't.
func (s *Store) changeSettings(change func(*settings)) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	path := filepath.Join(s.dir, "settings.json")
	if u := (*unparsed)(nil); s.setErr != nil && !errors.As(s.setErr, &u) {
		s.set, s.setErr = nil, nil
	}
	set := s.settingsLocked()
	if err := clearForWrite(path, s.setErr); err != nil {
		return err
	}
	s.setErr = nil // set aside: the bytes are kept, and the write below replaces nothing unread
	change(&set)
	// v0.52.0 reads only codexGoAgent (ADR 0108's going back): delete
	// after the v0.53.0 tag.
	set.CodexGoAgent = set.GoAgents[oldGoAgent]
	if err := writeJSON(path, set); err != nil {
		return err
	}
	s.set = &set
	return nil
}

// SleepAfter returns how long a chat idles before its agent sleeps; 0:
// never.
func (s *Store) SleepAfter() time.Duration {
	s.mu.Lock()
	defer s.mu.Unlock()
	if m := s.settingsLocked().SleepAfterMinutes; m != nil {
		return time.Duration(*m) * time.Minute
	}
	return defaultSleepAfter
}

// SetSleepAfter remembers how long a chat idles before its agent sleeps.
func (s *Store) SetSleepAfter(d time.Duration) error {
	m := int(d / time.Minute)
	return s.changeSettings(func(set *settings) { set.SleepAfterMinutes = &m })
}

// DebugLog says whether the log has DEBUG lines (ADR 0038).
func (s *Store) DebugLog() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.settingsLocked().DebugLog
}

// SetDebugLog remembers whether the log has DEBUG lines.
func (s *Store) SetDebugLog(on bool) error {
	return s.changeSettings(func(set *settings) { set.DebugLog = on })
}

// KeepTranscripts says whether Nushi keeps its own copy of chats'
// transcripts (ADR 0047); on until turned off.
func (s *Store) KeepTranscripts() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	keep := s.settingsLocked().KeepTranscripts
	return keep == nil || *keep
}

// SetKeepTranscripts remembers whether Nushi keeps copies of transcripts.
func (s *Store) SetKeepTranscripts(on bool) error {
	return s.changeSettings(func(set *settings) { set.KeepTranscripts = &on })
}

// TranscriptDays is how many days a transcript's copy is kept after it
// was last written; 0: for good.
func (s *Store) TranscriptDays() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.settingsLocked().TranscriptDays
}

// SetTranscriptDays remembers how many days copies are kept; 0: for good.
func (s *Store) SetTranscriptDays(days int) error {
	return s.changeSettings(func(set *settings) { set.TranscriptDays = days })
}

// CheckUpdates says whether the daemon asks GitHub for a newer release;
// on until turned off.
func (s *Store) CheckUpdates() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	on := s.settingsLocked().CheckUpdates
	return on == nil || *on
}

// SetCheckUpdates remembers whether the daemon checks for a newer release.
func (s *Store) SetCheckUpdates(on bool) error {
	return s.changeSettings(func(set *settings) { set.CheckUpdates = &on })
}

// GoAgent says whether the agent named name runs through Nushi's Go agent
// rather than its adapter (ADR 0142); off until turned on.
func (s *Store) GoAgent(name string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.settingsLocked().GoAgents[name]
}

// SetGoAgent remembers whether the agent named name runs through the Go
// agent.
func (s *Store) SetGoAgent(name string, on bool) error {
	return s.changeSettings(func(set *settings) {
		set.GoAgents = maps.Clone(set.GoAgents)
		if on {
			if set.GoAgents == nil {
				set.GoAgents = map[string]bool{}
			}
			set.GoAgents[name] = true
		} else {
			delete(set.GoAgents, name)
		}
	})
}
