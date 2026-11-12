package updates

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"testing/synctest"

	"github.com/afrase/nushi/internal/model"
)

// brew is a fake Homebrew: cask is installed, at version once an upgrade
// went through (unless stale: the tap doesn't have it yet); an upgrade
// waits on hold when there is one, and fails with err.
type brew struct {
	mu       sync.Mutex
	cask     string
	version  string // what an upgrade brings
	stale    bool
	err      error
	hold     chan struct{}
	upgraded []string
	at       string
}

func (b *brew) Installed() string { return b.cask }

func (b *brew) Has(cask, version string) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return cask == b.cask && version == b.at
}

func (b *brew) Upgrade(_ context.Context, cask, _ string) (string, error) {
	if b.hold != nil {
		<-b.hold
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	b.upgraded = append(b.upgraded, cask)
	if b.err != nil {
		return "==> Upgrading 1 outdated package\nError: " + b.err.Error() + "\n", b.err
	}
	if !b.stale {
		b.at = b.version
	}
	return "==> Upgrading 1 outdated package\n", nil
}

// found is a service that has found 0.29.0, with b as its Homebrew.
func found(t *testing.T, b Homebrew, ev *events) *Service {
	t.Helper()
	ask := func(context.Context) (string, error) { return "v0.29.0", nil }
	s := New(ask, &prefs{on: true}, "0.28.1", "https://github.com/afrase/nushi", ev.publish)
	if b != nil {
		s.Brew = b
	}
	if got, err := s.Check(t.Context()); err != nil || got.Version != "0.29.0" {
		t.Fatalf("check: %+v %v", got, err)
	}
	return s
}

// Install upgrades the cask that installed Nushi and says so as it goes:
// installing, then installed at the version found. The restart waits for
// it, and a check meanwhile keeps its state.
func TestInstall(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		var ev events
		b := &brew{cask: "nushi@beta", version: "0.29.0", hold: make(chan struct{})}
		s := found(t, b, &ev)
		if err := s.Install(); err != nil {
			t.Fatal(err)
		}
		synctest.Wait()
		if got := s.Get(); !got.Installing || got.InstallError != "" || !s.Busy() || ev.got[len(ev.got)-1] != got {
			t.Fatalf("installing: %+v, published %+v", got, ev.got)
		}
		if err := s.Install(); !errors.Is(err, ErrInstalling) {
			t.Fatalf("a second install: %v", err)
		}
		if got, err := s.Check(t.Context()); err != nil || !got.Installing {
			t.Fatalf("a check while installing: %+v %v", got, err)
		}
		close(b.hold)
		synctest.Wait()
		got := s.Get()
		if got.Installing || got.InstallError != "" || got.Installed != "0.29.0" || s.Busy() || ev.got[len(ev.got)-1] != got {
			t.Fatalf("installed: %+v, published %+v", got, ev.got)
		}
		if len(b.upgraded) != 1 || b.upgraded[0] != "nushi@beta" {
			t.Fatalf("upgraded %q", b.upgraded)
		}
	})
}

// A failed upgrade says why, in Homebrew's words, and can be tried again;
// the error goes when another install starts, and with a newer version.
func TestInstallFails(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		var ev events
		b := &brew{cask: "nushi", version: "0.29.0", err: errors.New("brew upgrade: Cask 'nushi' is unavailable")}
		s := found(t, b, &ev)
		if err := s.Install(); err != nil {
			t.Fatal(err)
		}
		synctest.Wait()
		got := s.Get()
		if got.Installing || got.InstallError != "brew upgrade: Cask 'nushi' is unavailable" || got.Installed != "" {
			t.Fatalf("failed: %+v", got)
		}
		if got, err := s.Check(t.Context()); err != nil || got.InstallError == "" {
			t.Fatalf("a check of the same version keeps the error: %+v %v", got, err)
		}
		b.mu.Lock()
		b.err, b.hold = nil, make(chan struct{})
		b.mu.Unlock()
		if err := s.Install(); err != nil {
			t.Fatal(err)
		}
		synctest.Wait()
		if got := s.Get(); !got.Installing || got.InstallError != "" {
			t.Fatalf("trying again: %+v", got)
		}
		close(b.hold)
		synctest.Wait()
		if got := s.Get(); got.Installed != "0.29.0" || got.InstallError != "" {
			t.Fatalf("the second try: %+v", got)
		}
	})
}

// An upgrade that goes through without bringing the version is a failure
// too: the release is on GitHub before its cask is in the tap.
func TestInstallBeforeTheCaskHasIt(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		var ev events
		s := found(t, &brew{cask: "nushi", version: "0.29.0", stale: true}, &ev)
		if err := s.Install(); err != nil {
			t.Fatal(err)
		}
		synctest.Wait()
		got := s.Get()
		if got.Installing || got.Installed != "" || !strings.Contains(got.InstallError, "Homebrew doesn't have 0.29.0 yet") {
			t.Fatalf("%+v", got)
		}
		// A newer version found later doesn't carry the old one's error.
		s.latest = func(context.Context) (string, error) { return "v0.29.1", nil }
		if got, err := s.Check(t.Context()); err != nil || got.Version != "0.29.1" || got.InstallError != "" {
			t.Fatalf("a newer version: %+v %v", got, err)
		}
	})
}

// Nothing to install with, or nothing to install: refused, and Homebrew
// isn't run.
func TestInstallRefused(t *testing.T) {
	var ev events
	if err := found(t, nil, &ev).Install(); !errors.Is(err, ErrNotHomebrew) {
		t.Fatalf("without Homebrew: %v", err)
	}
	zip := &brew{} // no cask installed it
	if err := found(t, zip, &ev).Install(); !errors.Is(err, ErrNotHomebrew) || zip.upgraded != nil {
		t.Fatalf("not Homebrew's: %v, upgraded %q", err, zip.upgraded)
	}
	b := &brew{cask: "nushi"}
	s := New(func(context.Context) (string, error) { return "v0.28.1", nil }, &prefs{on: true}, "0.28.1", "", ev.publish)
	s.Brew = b
	if err := s.Install(); !errors.Is(err, ErrNoUpdate) || b.upgraded != nil || s.Get() != (model.Update{}) {
		t.Fatalf("nothing newer: %v, upgraded %q, %+v", err, b.upgraded, s.Get())
	}
}
