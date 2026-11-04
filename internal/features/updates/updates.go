// Package updates asks GitHub for Nushi's latest release, at start and
// every 2 hours while the setting is on, and says when it's newer than
// the daemon's own version: the app shows it. One check per Mac, however
// many windows; nothing of the user's is sent (no token).
package updates

import (
	"context"
	"errors"
	"log/slog"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Latest is the tag ("v0.1.17") of the repository's latest release,
// neither a draft nor a pre-release (internal/githubapi).
type Latest func(ctx context.Context) (tag string, err error)

// Prefs keeps whether the daemon checks (internal/store).
type Prefs interface {
	CheckUpdates() bool
	SetCheckUpdates(on bool) error
}

// Service checks for a newer release and keeps what it found.
type Service struct {
	latest  Latest
	prefs   Prefs
	current string // the daemon's version; "" for a build that isn't a release
	web     string // the repository's page, for a release's link
	publish func(model.Event)

	// Every is how often it asks while the setting is on.
	Every time.Duration

	checking sync.Mutex // one check at a time
	mu       sync.Mutex
	found    model.Update
	kick     chan struct{}
}

// New returns the service; Run checks. current is the daemon's own version
// (api.Release), web the repository's page ("https://github.com/afrase/nushi").
func New(latest Latest, prefs Prefs, current, web string, publish func(model.Event)) *Service {
	return &Service{latest: latest, prefs: prefs, current: strings.TrimPrefix(current, "v"), web: web, publish: publish,
		Every: 2 * time.Hour, kick: make(chan struct{}, 1)}
}

// Run checks at once and then every Every while the setting is on, and
// at once when it's turned on, until ctx ends. A failure is quiet (a
// DEBUG line): the next tick asks again.
func (s *Service) Run(ctx context.Context) {
	tick := time.NewTicker(s.Every)
	defer tick.Stop()
	for {
		if s.prefs.CheckUpdates() {
			if _, err := s.check(ctx, true); err != nil {
				slog.Debug("update check failed", "err", err)
			}
		}
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
		case <-s.kick:
		}
	}
}

// Get is what the last check found.
func (s *Service) Get() model.Update {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.found
}

// SetOn turns the checks on or off. Off forgets a newer release found;
// on checks at once.
func (s *Service) SetOn(on bool) error {
	if err := s.prefs.SetCheckUpdates(on); err != nil {
		return err
	}
	if on {
		select {
		case s.kick <- struct{}{}:
		default: // one is due already
		}
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.found.Version, s.found.URL = "", ""
	found := s.found
	s.publish(model.Event{Update: &found}) // under mu: a check ending now publishes before, or not at all
	return nil
}

// Check asks GitHub now, whatever the setting, and says what it found.
func (s *Service) Check(ctx context.Context) (model.Update, error) {
	return s.check(ctx, false)
}

// check is Check; auto is Run's, whose answer is dropped when the checks
// were turned off while GitHub was asked (else a newer release found
// would come back after Off forgot it, until a restart).
func (s *Service) check(ctx context.Context, auto bool) (model.Update, error) {
	s.checking.Lock()
	defer s.checking.Unlock()
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	tag, err := s.latest(ctx)
	if err != nil {
		return s.Get(), err
	}
	v := strings.TrimPrefix(tag, "v")
	if _, ok := parse(v); !ok {
		return s.Get(), errors.New("the latest release's tag isn't a version: " + tag)
	}
	found := model.Update{Latest: v, Checked: time.Now()}
	newer := s.current != "" && Compare(v, s.current) > 0
	if newer {
		found.Version, found.URL = v, s.web+"/releases/tag/"+url.PathEscape(tag)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if auto && !s.prefs.CheckUpdates() {
		return s.found, nil
	}
	before := s.found.Latest
	s.found = found
	if v != before {
		slog.Info("latest release", "version", v, "running", s.current, "newer", newer)
	} else {
		slog.Debug("update check", "latest", v)
	}
	s.publish(model.Event{Update: &found})
	return found, nil
}

// On says whether the checks are on.
func (s *Service) On() bool { return s.prefs.CheckUpdates() }
