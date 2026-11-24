// Package relayupdate replaces a running relay's binary with the newest
// stable release's, when a person asks (`nushi-relay -update`, ADR 0149):
// it asks GitHub for the latest release, downloads this machine's tarball
// and its .sha256, checks one against the other, unpacks the one file,
// runs it once with -version, and renames it over this binary.
package relayupdate

import (
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"time"
)

// Repo is the GitHub repository whose releases a relay updates from.
const Repo = "afrase/nushi"

// GitHubAPI is GitHub's API, which says which release is the latest.
const GitHubAPI = "https://api.github.com"

// limits caps what an update reads: a release's tarball is about 35 MB
// and the relay in it about 55 MB (ADR 0113), so 256 MB leaves room to
// grow and still stops an endless answer.
type limits struct {
	json, sum, tarball, binary int64
}

var defaultLimits = limits{json: 1 << 20, sum: 512, tarball: 256 << 20, binary: 256 << 20}

// Updater is one run of `nushi-relay -update`. New fills it for the real
// thing; tests put a fake GitHub, verifier and restart in its place.
type Updater struct {
	Version string // this relay's own, X.Y.Z or X.Y.Z-beta.N
	Unit    string // the systemd unit to restart after an install, or ""
	Out     io.Writer

	API     string       // GitHub's API
	Client  *http.Client // NewClient's
	Exe     string       // this binary ("": os.Executable)
	GOOS    string
	GOARCH  string
	Timeout time.Duration // the whole download and install

	// Verify checks the new binary at path before it is installed
	// (CheckBinary).
	Verify func(ctx context.Context, path, version string) error
	// Restart restarts the unit after an install (Systemctl).
	Restart func(ctx context.Context, unit string) error

	limits limits
}

// New is the Updater for this binary at version, restarting unit after an
// install when it isn't "", writing what it does to out.
func New(version, unit string, out io.Writer) *Updater {
	return &Updater{
		Version: version, Unit: unit, Out: out,
		API: GitHubAPI, Client: NewClient(nil),
		GOOS: runtime.GOOS, GOARCH: runtime.GOARCH,
		Timeout: 5 * time.Minute,
		Verify:  CheckBinary, Restart: Systemctl,
		limits: defaultLimits,
	}
}

// Run updates this binary to the latest stable release if that is newer,
// and says what it did. An error means nothing was installed, but for a
// failed restart, which comes after.
func (u *Updater) Run(ctx context.Context) error {
	current, err := u.preflight()
	if err != nil {
		return err
	}
	fetchCtx, cancel := context.WithTimeout(ctx, u.Timeout)
	defer cancel()
	rel, latest, err := u.latest(fetchCtx)
	if err != nil {
		return err
	}
	switch c := latest.compare(current); {
	case c == 0:
		u.sayf("nushi-relay %s is the latest", current)
		return nil
	case c < 0:
		u.sayf("nushi-relay %s is newer than the latest release, %s; nothing to do", current, latest)
		return nil
	}
	u.sayf("nushi-relay %s is installed; the latest release is %s", current, latest)
	target, err := u.install(fetchCtx, rel, latest)
	if err != nil {
		return err
	}
	u.sayf("Installed nushi-relay %s at %s", latest, target)
	if u.Unit == "" {
		u.sayf("Restart its service to run it: sudo systemctl restart nushi-relay")
		return nil
	}
	if err := u.Restart(ctx, u.Unit); err != nil {
		return fmt.Errorf("installed %s, but its restart failed: %w", latest, err)
	}
	u.sayf("Restarted %s", u.Unit)
	return nil
}

// preflight refuses what needs no request to refuse: a bad unit name, a
// relay not built from a release, a system a release has no relay for.
func (u *Updater) preflight() (version, error) {
	if u.Unit != "" {
		if err := CheckUnit(u.Unit); err != nil {
			return version{}, err
		}
	}
	current, ok := parseVersion(u.Version)
	if !ok {
		return version{}, fmt.Errorf("this relay's version is %q, not a release's: it has nothing to compare; install a release's relay by hand (docs/remote.md)", u.Version)
	}
	if _, ok := machines[u.GOARCH]; u.GOOS != "linux" || !ok {
		return version{}, fmt.Errorf("a release has no relay for %s/%s", u.GOOS, u.GOARCH)
	}
	return current, nil
}

// install downloads, checks and installs the release's relay in this
// binary's place, and returns that place. On an error this binary is as
// it was and nothing is left beside it.
func (u *Updater) install(ctx context.Context, rel release, latest version) (string, error) {
	target, old, err := u.target()
	if err != nil {
		return "", err
	}
	if err := probe(filepath.Dir(target)); err != nil {
		return "", err
	}
	name := fmt.Sprintf("nushi-relay-%s-linux-%s.tar.gz", latest, u.GOARCH)
	tarAsset, ok := rel.find(name)
	sumAsset, sumOK := rel.find(name + ".sha256")
	if !ok || !sumOK {
		return "", fmt.Errorf("release %s has no %s and its .sha256", rel.Tag, name)
	}
	u.sayf("Downloading %s", name)
	sum, err := u.download(ctx, sumAsset, u.limits.sum)
	if err != nil {
		return "", err
	}
	tarball, err := u.download(ctx, tarAsset, u.limits.tarball)
	if err != nil {
		return "", err
	}
	if err := checkSum(tarball, sum, name); err != nil {
		return "", err
	}
	u.sayf("Checked it against %s.sha256", name)
	staged, err := stageBinary(tarball, target, u.limits.binary)
	if err != nil {
		return "", writeErr(filepath.Dir(target), err)
	}
	err = os.Chmod(staged.Name(), old.Mode().Perm())
	if err == nil {
		err = copyOwner(staged.Name(), old)
	}
	if err == nil {
		err = u.Verify(ctx, staged.Name(), latest.String())
	}
	if err != nil {
		staged.Discard()
		return "", fmt.Errorf("checking the new relay: %w", err)
	}
	if err := staged.Commit(); err != nil {
		return "", fmt.Errorf("putting the new relay at %s: %w", target, err)
	}
	return target, nil
}

// target is this binary's real path, links resolved, and what it is.
func (u *Updater) target() (string, os.FileInfo, error) {
	exe := u.Exe
	if exe == "" {
		var err error
		if exe, err = os.Executable(); err != nil {
			return "", nil, fmt.Errorf("finding this binary: %w", err)
		}
	}
	path, err := filepath.EvalSymlinks(exe)
	if err != nil {
		return "", nil, fmt.Errorf("finding this binary: %w", err)
	}
	fi, err := os.Stat(path)
	if err != nil {
		return "", nil, fmt.Errorf("finding this binary: %w", err)
	}
	return path, fi, nil
}

// probe makes sure dir can be written before anything is downloaded.
func probe(dir string) error {
	f, err := os.CreateTemp(dir, ".nushi-relay-probe-*")
	if err != nil {
		return writeErr(dir, err)
	}
	_ = f.Close()
	_ = os.Remove(f.Name())
	return nil
}

// writeErr says to run as root when dir can't be written for want of
// permission.
func writeErr(dir string, err error) error {
	if errors.Is(err, fs.ErrPermission) {
		return fmt.Errorf("can't write %s: run it as root (sudo nushi-relay -update)", dir)
	}
	return err
}

// sayf writes one line of what the update did.
func (u *Updater) sayf(format string, args ...any) {
	_, _ = fmt.Fprintf(u.Out, format+"\n", args...)
}
