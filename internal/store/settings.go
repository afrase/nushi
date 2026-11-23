package store

import (
	"fmt"
	"log/slog"
	"maps"
	"path/filepath"
	"time"

	"github.com/afrase/nushi/internal/model"
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

// current is settings.json, read once and then kept (a hand edit while
// the daemon runs is seen at its next start); one that doesn't parse is
// set aside and read as empty (readJSON). One that can't be read at all
// reads as the defaults and isn't kept, so it's read again next time
// (loadSettingsLocked). Once read, it takes no lock.
func (s *Store) current() settings {
	if set := s.set.Load(); set != nil {
		return *set
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	set, _ := s.loadSettingsLocked()
	return set
}

// loadSettingsLocked is current, under mu, with the read's error: a read that
// failed for any reason but no file or a parse error (EACCES, EIO) is
// never kept, and is logged only when it changes.
func (s *Store) loadSettingsLocked() (settings, error) {
	if set := s.set.Load(); set != nil {
		return *set, nil
	}
	var set settings
	if _, err := readJSON(filepath.Join(s.dir, "settings.json"), &set); err != nil {
		if s.setErr == nil || s.setErr.Error() != err.Error() {
			slog.Warn("reading settings.json", "err", err)
		}
		s.setErr = err
		return settings{}, err
	}
	s.setErr = nil
	if set.CodexGoAgent { // the old key's read: delete after v0.54.0
		if _, ok := set.GoAgents[oldGoAgent]; !ok {
			if set.GoAgents == nil {
				set.GoAgents = map[string]bool{}
			}
			set.GoAgents[oldGoAgent] = true
		}
		set.CodexGoAgent = false
	}
	s.set.Store(&set)
	return set, nil
}

// changeSettings applies change to settings.json, and keeps the result
// once it's written. A file that can't be read is never written over: the
// change is refused, naming it.
func (s *Store) changeSettings(change func(*settings)) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	set, err := s.loadSettingsLocked()
	if err != nil {
		return fmt.Errorf("settings.json can't be read, so it isn't written over: %w", err)
	}
	change(&set)
	// v0.52.0 reads only codexGoAgent (ADR 0108's going back): delete
	// after the v0.53.0 tag.
	set.CodexGoAgent = set.GoAgents[oldGoAgent]
	path := filepath.Join(s.dir, "settings.json")
	if err := writeJSON(path, set); err != nil {
		return err
	}
	s.set.Store(&set)
	return nil
}

// ChangeSettings makes change in one write of settings.json: all of it is
// written, or, refused, none.
func (s *Store) ChangeSettings(c model.SettingsChange) error {
	return s.changeSettings(func(set *settings) {
		if c.SleepAfter != nil {
			m := int(*c.SleepAfter / time.Minute)
			set.SleepAfterMinutes = &m
		}
		if c.DebugLog != nil {
			set.DebugLog = *c.DebugLog
		}
		if c.KeepTranscripts != nil {
			set.KeepTranscripts = new(*c.KeepTranscripts)
		}
		if c.TranscriptDays != nil {
			set.TranscriptDays = *c.TranscriptDays
		}
		if c.CheckUpdates != nil {
			set.CheckUpdates = new(*c.CheckUpdates)
		}
		for name, on := range c.GoAgents {
			setGoAgent(set, name, on)
		}
	})
}

// SleepAfter returns how long a chat idles before its agent sleeps; 0:
// never.
func (s *Store) SleepAfter() time.Duration {
	if m := s.current().SleepAfterMinutes; m != nil {
		return time.Duration(*m) * time.Minute
	}
	return defaultSleepAfter
}

// DebugLog says whether the log has DEBUG lines (ADR 0038).
func (s *Store) DebugLog() bool {
	return s.current().DebugLog
}

// SetDebugLog remembers whether the log has DEBUG lines.
func (s *Store) SetDebugLog(on bool) error {
	return s.changeSettings(func(set *settings) { set.DebugLog = on })
}

// KeepTranscripts says whether Nushi keeps its own copy of chats'
// transcripts (ADR 0047); on until turned off.
func (s *Store) KeepTranscripts() bool {
	keep := s.current().KeepTranscripts
	return keep == nil || *keep
}

// SetKeepTranscripts remembers whether Nushi keeps copies of transcripts.
func (s *Store) SetKeepTranscripts(on bool) error {
	return s.changeSettings(func(set *settings) { set.KeepTranscripts = &on })
}

// TranscriptDays is how many days a transcript's copy is kept after it
// was last written; 0: for good.
func (s *Store) TranscriptDays() int {
	return s.current().TranscriptDays
}

// SetTranscriptDays remembers how many days copies are kept; 0: for good.
func (s *Store) SetTranscriptDays(days int) error {
	return s.changeSettings(func(set *settings) { set.TranscriptDays = days })
}

// CheckUpdates says whether the daemon asks GitHub for a newer release;
// on until turned off.
func (s *Store) CheckUpdates() bool {
	on := s.current().CheckUpdates
	return on == nil || *on
}

// SetCheckUpdates remembers whether the daemon checks for a newer release.
func (s *Store) SetCheckUpdates(on bool) error {
	return s.changeSettings(func(set *settings) { set.CheckUpdates = &on })
}

// GoAgent says whether the agent named name runs through Nushi's Go agent
// rather than its adapter (ADR 0142); off until turned on.
func (s *Store) GoAgent(name string) bool {
	return s.current().GoAgents[name]
}

// SetGoAgent remembers whether the agent named name runs through the Go
// agent.
func (s *Store) SetGoAgent(name string, on bool) error {
	return s.changeSettings(func(set *settings) { setGoAgent(set, name, on) })
}

// setGoAgent turns name's Go agent on or off in set, its map a copy: the
// one kept is replaced only once the change is written.
func setGoAgent(set *settings, name string, on bool) {
	set.GoAgents = maps.Clone(set.GoAgents)
	if on {
		if set.GoAgents == nil {
			set.GoAgents = map[string]bool{}
		}
		set.GoAgents[name] = true
	} else {
		delete(set.GoAgents, name)
	}
}
