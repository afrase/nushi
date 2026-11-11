// Package updates asks GitHub for Nushi's latest release, at start and
// every 2 hours while the setting is on, and says when it's newer than
// the daemon's own version: the app shows it. For a Nushi that follows
// beta versions (ADR 0108) a pre-release counts too. One check per Mac,
// however many windows; nothing of the user's is sent (no token). Asked
// by the Mac's app, it has Homebrew install the newer one (install.go,
// ADR 0109).
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

// Tags is the tags of the repository's newest releases, pre-releases
// among them (internal/githubapi).
type Tags func(ctx context.Context) (tags []string, err error)

// Prefs keeps whether the daemon checks (internal/store).
type Prefs interface {
	CheckUpdates() bool
	SetCheckUpdates(on bool) error
}

// Homebrew is Homebrew's casks of Nushi (internal/homebrew): the way a
// newer version is installed (ADR 0109).
type Homebrew interface {
	// Installed is the cask that installed this Nushi; "" when none did.
	Installed() string
	// Has says whether cask is installed at version.
	Has(cask, version string) bool
	// Upgrade runs Homebrew's upgrade of cask and returns the end of what
	// it printed; its error is a sentence to show.
	Upgrade(ctx context.Context, cask string) (output string, err error)
}

// What Install refuses with.
var (
	ErrNotHomebrew = errors.New("Homebrew didn't install this Nushi")
	ErrNoUpdate    = errors.New("no newer version of Nushi was found")
	ErrInstalling  = errors.New("the update is installing already")
)

// Service checks for a newer release and keeps what it found.
type Service struct {
	latest  Latest
	prefs   Prefs
	current string // the daemon's version; "" for a build that isn't a release
	web     string // the repository's page, for a release's link
	publish func(model.Event)

	// Every is how often it asks while the setting is on.
	Every time.Duration
	// Tags is asked in Latest's place by a Nushi that follows beta
	// versions (ADR 0108): one that is a beta itself, or whose Beta says
	// so. nil: a beta version is never found.
	Tags Tags
	// Beta says whether this Nushi was installed to follow beta versions
	// (Homebrew's nushi@beta cask); nil: no.
	Beta func() bool
	// Brew installs the newer version (Install); nil: nothing does.
	Brew Homebrew

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
	tag, err := s.newest(ctx)
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
	// An install's state stays; its error goes with the version it was
	// about.
	found.Installing, found.Installed = s.found.Installing, s.found.Installed
	if found.Version == s.found.Version {
		found.InstallError = s.found.InstallError
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

// newest is the tag a check compares with: GitHub's latest release, or
// for a Nushi that follows beta versions the highest version among the
// newest releases, a pre-release or not (a release newer than every beta
// wins, so a beta moves on to its release).
func (s *Service) newest(ctx context.Context) (string, error) {
	running, _ := parse(s.current)
	if s.Tags == nil || len(running.pre) == 0 && (s.Beta == nil || !s.Beta()) {
		return s.latest(ctx)
	}
	tags, err := s.Tags(ctx)
	if err != nil {
		return "", err
	}
	best := ""
	for _, tag := range tags {
		v := strings.TrimPrefix(tag, "v")
		if _, ok := parse(v); ok && (best == "" || Compare(v, strings.TrimPrefix(best, "v")) > 0) {
			best = tag
		}
	}
	if best == "" {
		return s.latest(ctx) // none yet: its answer says so
	}
	return best, nil
}

// On says whether the checks are on.
func (s *Service) On() bool { return s.prefs.CheckUpdates() }
