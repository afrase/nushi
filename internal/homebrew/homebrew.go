// Package homebrew is Homebrew as Nushi's own update needs it (ADR 0109):
// which of the tap's two casks installed Nushi, found by a look at the
// Caskroom's folders, and that cask's upgrade, `brew update` and then
// `brew upgrade --cask <cask>`. The arguments are fixed and no shell
// takes part: nothing a caller or the network says reaches a command
// line.
package homebrew

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/ansi"
	"github.com/afrase/nushi/internal/secrets"
)

// The tap's casks (ADR 0108). They install the same app and conflict, so
// a Mac has one of them.
const (
	Cask     = "nushi"      // releases only
	BetaCask = "nushi@beta" // beta versions too, and each release that passes them
)

// Timeout bounds an upgrade, the download included.
const Timeout = 15 * time.Minute

// maxOutput is how much of what brew printed is kept: its end, where a
// failure says why.
const maxOutput = 64 << 10

// quiet is what keeps brew from asking or advising: nobody reads its
// output as it runs, and it has no terminal to ask on. Homebrew 7 asks
// before an upgrade only on a terminal, and HOMEBREW_NO_ASK turns that
// off anyway; NONINTERACTIVE is what its installer and scripts under it
// read (brew itself doesn't).
var quiet = []string{"NONINTERACTIVE=1", "HOMEBREW_NO_ASK=1", "HOMEBREW_NO_ENV_HINTS=1", "HOMEBREW_NO_COLOR=1"}

// Brew is Homebrew on this Mac.
type Brew struct {
	// Prefixes are where Homebrew may be: each holds bin/brew and
	// Caskroom. A prefix elsewhere isn't seen (ADR 0061).
	Prefixes []string
	// Apps are the folders a cask puts Nushi.app in, and Exe the daemon's
	// own executable: only a Nushi running from one of them is the cask's
	// to upgrade, never a build run from elsewhere (as the app's
	// homebrewCask says too).
	Apps []string
	Exe  string
	// Env is the environment brew runs in, before what keeps it quiet:
	// the login shell's (internal/shellenv), which has the user's proxy
	// and Homebrew settings.
	Env func() []string
	// Run runs name with args in env and returns the end of what it
	// printed, stdout and stderr together; tests put a fake in its place.
	Run func(ctx context.Context, env []string, name string, args ...string) ([]byte, error)
}

// New is Homebrew in its usual places (none off the Mac: no cask installs
// Nushi there), run in env, for the daemon running as exe of the user
// whose home is home.
func New(env func() []string, exe, home string) *Brew {
	return &Brew{Prefixes: prefixes, Apps: []string{"/Applications", filepath.Join(home, "Applications")}, Exe: exe, Env: env, Run: run}
}

// Installed is the cask that installed this Nushi, the one to upgrade:
// nushi@beta if its Caskroom folder is there, else nushi; "" when
// neither is, or when the daemon doesn't run from a cask's Nushi.app.
// Asked each time it matters, so swapping casks needs no restart.
func (b *Brew) Installed() string {
	if !slices.ContainsFunc(b.Apps, func(apps string) bool {
		return strings.HasPrefix(b.Exe, filepath.Join(apps, "Nushi.app")+string(filepath.Separator))
	}) {
		return ""
	}
	for _, cask := range []string{BetaCask, Cask} {
		if b.prefix(cask) != "" {
			return cask
		}
	}
	return ""
}

// Beta says whether Homebrew's nushi@beta cask is installed, wherever
// this daemon runs from: such a Mac follows beta versions (ADR 0108).
func (b *Brew) Beta() bool { return b.prefix(BetaCask) != "" }

// Has says whether cask is installed at version: its Caskroom folder has
// one of that name. A version that can't be a folder's name is never
// there.
func (b *Brew) Has(cask, version string) bool {
	prefix := b.prefix(cask)
	if prefix == "" || !versionName(version) {
		return false
	}
	return isDir(filepath.Join(prefix, "Caskroom", cask, version))
}

// Upgrade runs `brew update` and `brew upgrade --cask cask` with the brew
// of the prefix whose Caskroom has cask, and returns the end of what they
// printed. cask is one of the tap's two, or it's refused. The error is a
// sentence to show: brew's own last "Error:" line when it printed one,
// or where to allow it when macOS refused the change to the app.
func (b *Brew) Upgrade(ctx context.Context, cask string) (string, error) {
	prefix := b.prefix(cask)
	if prefix == "" {
		return "", fmt.Errorf("Homebrew has no cask %q installed", cask)
	}
	ctx, cancel := context.WithTimeout(ctx, Timeout)
	defer cancel()
	brew := filepath.Join(prefix, "bin", "brew")
	env := append(slices.Clone(b.Env()), quiet...) // exec takes a name's last value
	var out []byte
	for _, args := range [][]string{{"update"}, {"upgrade", "--cask", cask}} {
		printed, err := b.Run(ctx, env, brew, args...)
		out = append(out, printed...)
		out = out[max(0, len(out)-maxOutput):]
		if err != nil {
			return plain(out), failure(ctx, args[0], plain(printed), err)
		}
	}
	return plain(out), nil
}

// plain is what brew printed as text to show or log: without a
// terminal's escapes, and with anything shaped like a key or token
// hidden.
func plain(printed []byte) string {
	return secrets.Mask(ansi.Strip(strings.ToValidUTF8(string(printed), "")), "[hidden]", nil)
}

// failure says why brew's command (update or upgrade) failed, from what
// it printed.
func failure(ctx context.Context, command, printed string, err error) error {
	step, low := "brew "+command, strings.ToLower(printed)
	switch {
	case errors.Is(ctx.Err(), context.DeadlineExceeded):
		return fmt.Errorf("%s took over %d minutes", step, int(Timeout.Minutes()))
	case command == "upgrade" && (strings.Contains(low, "app management") || strings.Contains(low, "operation not permitted")):
		// macOS's App Management refused brew, the daemon's child, its
		// change to the app. Which words that fails with is unverified
		// (ADR 0109): these are Homebrew's own and the system's EPERM.
		return errors.New("macOS didn't let Nushi Daemon replace the app: allow it in System Settings › Privacy & Security › App Management, then try again")
	}
	if line := errorLine(printed); line != "" {
		return fmt.Errorf("%s: %s", step, line)
	}
	return fmt.Errorf("%s: %w", step, err) // it printed nothing: brew isn't there, or it was killed
}

// errorLine is the last line brew began with "Error:", without that
// word, else the last line it printed; 200 characters at most.
func errorLine(printed string) string {
	last := ""
	for _, line := range slices.Backward(strings.Split(printed, "\n")) {
		line = strings.TrimSpace(line)
		if after, ok := strings.CutPrefix(line, "Error:"); ok {
			last = strings.TrimSpace(after)
			break
		}
		if last == "" {
			last = line
		}
	}
	if r := []rune(last); len(r) > 200 {
		last = string(r[:200]) + "…"
	}
	return last
}

// prefix is the prefix whose Caskroom has cask, one of the tap's two; ""
// for none, and for any other name.
func (b *Brew) prefix(cask string) string {
	if cask != Cask && cask != BetaCask {
		return ""
	}
	for _, p := range b.Prefixes {
		if isDir(filepath.Join(p, "Caskroom", cask)) {
			return p
		}
	}
	return ""
}

// versionName says whether version can be a Caskroom folder's name: a
// version's letters, digits, dots, dashes and plus signs, and no way to
// another folder (it comes from GitHub's answer).
func versionName(version string) bool {
	if strings.Trim(version, ".") == "" {
		return false
	}
	for _, r := range version {
		switch {
		case r >= '0' && r <= '9', r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r == '.', r == '-', r == '+':
		default:
			return false
		}
	}
	return true
}

func isDir(path string) bool {
	st, err := os.Stat(path)
	return err == nil && st.IsDir()
}
