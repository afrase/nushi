package relayupdate

import (
	"archive/tar"
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// A newer release is installed in the relay's place: its bytes, the old
// mode, the old file replaced by the rename (a reader holding it open
// still reads the old bytes) and nothing left beside it.
func TestInstallsNewer(t *testing.T) {
	f := newFakeGitHub(t)
	f.publish(t, "v1.3.0", false, false, releaseFiles(t))
	r := f.newRun(t, "1.2.9")
	held, err := os.Open(r.exe)
	testcheck.NoErr(t, err)
	defer held.Close() //nolint:errcheck // a test's
	testcheck.NoErr(t, r.u.Run(t.Context()))

	want := []string{
		"nushi-relay 1.2.9 is installed; the latest release is 1.3.0",
		"Downloading nushi-relay-1.3.0-linux-arm64.tar.gz",
		"Checked it against nushi-relay-1.3.0-linux-arm64.tar.gz.sha256",
		"Installed nushi-relay 1.3.0 at " + r.exe,
		"Restart its service to run it: sudo systemctl restart nushi-relay",
	}
	if got := r.lines(); !slices.Equal(got, want) {
		t.Errorf("printed\n%s\nwant\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
	fi, err := os.Stat(r.exe)
	testcheck.NoErr(t, err)
	if b, _ := os.ReadFile(r.exe); string(b) != "new relay" || fi.Mode().Perm() != 0o751 {
		t.Errorf("installed %q, %v", b, fi.Mode())
	}
	buf := make([]byte, 32)
	if n, _ := held.Read(buf); string(buf[:n]) != "old relay" {
		t.Errorf("the old file was written over, not replaced: %q", buf[:n])
	}
	r.alone(t)
	if !slices.Equal(r.verified, []string{"1.3.0"}) || len(r.restarts) != 0 {
		t.Errorf("verified %v, restarted %v", r.verified, r.restarts)
	}
	for _, ua := range f.agents {
		if ua != "nushi-relay/1.2.9" {
			t.Errorf("User-Agent %q", ua)
		}
	}
}

// -restart-unit restarts the unit after an install, and only then.
func TestRestartsOnlyAfterAnInstall(t *testing.T) {
	f := newFakeGitHub(t)
	f.publish(t, "v1.3.0", false, false, releaseFiles(t))
	r := f.newRun(t, "1.2.9")
	r.u.Unit = "nushi-relay@main.service"
	testcheck.NoErr(t, r.u.Run(t.Context()))
	if lines := r.lines(); lines[len(lines)-1] != "Restarted nushi-relay@main.service" || !slices.Equal(r.restarts, []string{"nushi-relay@main.service"}) {
		t.Errorf("printed %q, restarted %v", lines, r.restarts)
	}

	for _, v := range []string{"1.3.0", "1.4.0"} {
		r := f.newRun(t, v)
		r.u.Unit = "nushi-relay"
		testcheck.NoErr(t, r.u.Run(t.Context()))
		if len(r.restarts) != 0 {
			t.Errorf("%s: restarted with nothing installed", v)
		}
	}

	r = f.newRun(t, "1.2.9")
	r.u.Unit = "nushi-relay"
	r.u.Restart = func(context.Context, string) error {
		return errors.New("exit status 5: unit nushi-relay.service not found")
	}
	err := r.u.Run(t.Context())
	if err == nil || !strings.Contains(err.Error(), "installed 1.3.0, but its restart failed: exit status 5: unit nushi-relay.service not found") {
		t.Errorf("a failed restart: %v", err)
	}
	if b, _ := os.ReadFile(r.exe); string(b) != "new relay" {
		t.Errorf("a failed restart: installed %q", b)
	}
}

// The same release, or an older one, does nothing and downloads nothing.
func TestEqualOrOlderDoesNothing(t *testing.T) {
	f := newFakeGitHub(t)
	f.publish(t, "v1.3.0", false, false, releaseFiles(t))
	for _, c := range []struct{ version, says string }{
		{"1.3.0", "nushi-relay 1.3.0 is the latest"},
		{"1.3.1", "nushi-relay 1.3.1 is newer than the latest release, 1.3.0; nothing to do"},
		{"1.3.1-beta.1", "nushi-relay 1.3.1-beta.1 is newer than the latest release, 1.3.0; nothing to do"},
		{"2.0.0", "nushi-relay 2.0.0 is newer than the latest release, 1.3.0; nothing to do"},
	} {
		r := f.newRun(t, c.version)
		testcheck.NoErr(t, r.u.Run(t.Context()))
		if got := r.lines(); !slices.Equal(got, []string{c.says}) {
			t.Errorf("%s: printed %q", c.version, got)
		}
		r.untouched(t)
	}
	for _, p := range f.seen() {
		if p != "/repos/afrase/nushi/releases/latest" {
			t.Errorf("asked for %s", p)
		}
	}
}

// A beta relay moves to its stable release.
func TestBetaMovesToStable(t *testing.T) {
	f := newFakeGitHub(t)
	f.publish(t, "v1.3.0", false, false, releaseFiles(t))
	r := f.newRun(t, "1.3.0-beta.4")
	testcheck.NoErr(t, r.u.Run(t.Context()))
	if b, _ := os.ReadFile(r.exe); string(b) != "new relay" {
		t.Errorf("installed %q", b)
	}
}

// A draft, a pre-release or a tag that isn't vX.Y.Z is refused.
func TestRefusesWhatIsNotAStableRelease(t *testing.T) {
	for _, c := range []struct {
		tag        string
		draft, pre bool
	}{
		{"v1.3.0", true, false},
		{"v1.3.0", false, true},
		{"v1.3.0-beta.1", false, false},
		{"1.3.0", false, false},
		{"v1.3", false, false},
		{"v01.3.0", false, false},
		{"v1.3.0.1", false, false},
		{"v1.3.+0", false, false},
		{"", false, false},
	} {
		f := newFakeGitHub(t)
		f.publish(t, c.tag, c.draft, c.pre, releaseFiles(t))
		r := f.newRun(t, "1.2.9")
		if err := r.u.Run(t.Context()); err == nil || !strings.Contains(err.Error(), "refused") {
			t.Errorf("%q draft %v pre %v: %v", c.tag, c.draft, c.pre, err)
		}
		r.untouched(t)
		if len(f.seen()) != 1 {
			t.Errorf("%q: downloaded %v", c.tag, f.seen())
		}
	}
}

// A release without this architecture's tarball, or its .sha256, says so.
func TestMissingAsset(t *testing.T) {
	f := newFakeGitHub(t)
	files := releaseFiles(t)
	f.publish(t, "v1.3.0", false, false, files)
	r := f.newRun(t, "1.2.9")
	r.u.GOARCH = "amd64"
	err := r.u.Run(t.Context())
	if err == nil || err.Error() != "release v1.3.0 has no nushi-relay-1.3.0-linux-amd64.tar.gz and its .sha256" {
		t.Errorf("no amd64: %v", err)
	}
	r.untouched(t)

	delete(files, "nushi-relay-1.3.0-linux-arm64.tar.gz.sha256")
	f = newFakeGitHub(t)
	f.publish(t, "v1.3.0", false, false, files)
	r = f.newRun(t, "1.2.9")
	if err := r.u.Run(t.Context()); err == nil || !strings.Contains(err.Error(), "has no nushi-relay-1.3.0-linux-arm64.tar.gz") {
		t.Errorf("no .sha256: %v", err)
	}
	r.untouched(t)
}

// Every bad download or tarball is refused and leaves the installed
// relay byte for byte as it was, with nothing beside it.
func TestRefusalsLeaveTheRelay(t *testing.T) {
	const name = tarName
	good := tarball(t, entry{name: "nushi-relay", body: "new relay"})
	withTarball := func(tb []byte) func(*fakeGitHub, *run) {
		return func(f *fakeGitHub, _ *run) {
			f.served[name], f.served[name+".sha256"] = tb, sumOf(tb)
		}
	}
	for _, c := range []struct {
		name  string
		setup func(*fakeGitHub, *run)
		says  string
	}{
		{"checksum mismatch", func(f *fakeGitHub, _ *run) { f.served[name+".sha256"] = sumOf([]byte("other")) }, "doesn't match its .sha256"},
		{"not a checksum", func(f *fakeGitHub, _ *run) { f.served[name+".sha256"] = []byte("nope  " + name) }, "doesn't start with a SHA-256"},
		{"short tarball", func(f *fakeGitHub, _ *run) { f.lies[name] = len(good) + 100 }, "downloading " + name},
		{"oversized tarball", func(_ *fakeGitHub, r *run) { r.u.limits.tarball = int64(len(good) - 1) }, "more than"},
		{"oversized .sha256", func(f *fakeGitHub, _ *run) {
			f.served[name+".sha256"] = append(sumOf(good), strings.Repeat(" ", 600)...)
		}, "more than 512"},
		{"oversized JSON", func(_ *fakeGitHub, r *run) { r.u.limits.json = 10 }, "more than 10"},
		{"a second entry", withTarball(tarball(t, entry{name: "nushi-relay", body: "new relay"}, entry{name: "extra", body: "x"})), `holds "extra" too`},
		{"a link", withTarball(tarball(t, entry{name: "nushi-relay", kind: tar.TypeSymlink, link: "/bin/sh"})), "isn't a regular file"},
		{"a folder", withTarball(tarball(t, entry{name: "nushi-relay", kind: tar.TypeDir})), "isn't a regular file"},
		{"a path", withTarball(tarball(t, entry{name: "bin/nushi-relay", body: "x"})), `holds "bin/nushi-relay"`},
		{"dots", withTarball(tarball(t, entry{name: "../nushi-relay", body: "x"})), `holds "../nushi-relay"`},
		{"dot slash", withTarball(tarball(t, entry{name: "./nushi-relay", body: "x"})), `holds "./nushi-relay"`},
		{"a wrong name", withTarball(tarball(t, entry{name: "nushid", body: "x"})), `holds "nushid"`},
		{"empty", withTarball(tarball(t)), "empty"},
		{"not gzip", withTarball([]byte("plain text")), "reading the tarball"},
		{"an oversized file", func(_ *fakeGitHub, r *run) { r.u.limits.binary = 4 }, "more than 4"},
		{"the verifier refuses", func(_ *fakeGitHub, r *run) {
			r.u.Verify = func(_ context.Context, path, _ string) error {
				if b, _ := os.ReadFile(path); string(b) != "new relay" {
					t.Errorf("verified %q", b)
				}
				return errors.New(`the new file's -version says "nushi-relay 1.2.0"`)
			}
		}, "checking the new relay: the new file's -version says"},
	} {
		f := newFakeGitHub(t)
		f.publish(t, "v1.3.0", false, false, map[string][]byte{name: good, name + ".sha256": sumOf(good)})
		r := f.newRun(t, "1.2.9")
		r.u.Unit = "nushi-relay"
		f.mu.Lock()
		c.setup(f, r)
		f.mu.Unlock()
		err := r.u.Run(t.Context())
		if err == nil || !strings.Contains(err.Error(), c.says) {
			t.Errorf("%s: %v, want %q", c.name, err, c.says)
		}
		r.untouched(t)
		if len(r.restarts) != 0 {
			t.Errorf("%s: restarted", c.name)
		}
	}
}

// A redirect to http, or an asset at an http address, is refused.
func TestRefusesHTTP(t *testing.T) {
	plain := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		t.Error("a request reached the plain server")
		w.WriteHeader(http.StatusTeapot)
	}))
	defer plain.Close()
	const name = tarName
	f := newFakeGitHub(t)
	f.publish(t, "v1.3.0", false, false, releaseFiles(t))
	f.mu.Lock()
	f.redirect[name] = plain.URL + "/files/" + name
	f.mu.Unlock()
	r := f.newRun(t, "1.2.9")
	if err := r.u.Run(t.Context()); err == nil || !strings.Contains(err.Error(), "not https") {
		t.Errorf("a redirect to http: %v", err)
	}
	r.untouched(t)

	r = f.newRun(t, "1.2.9")
	r.u.API = plain.URL
	if err := r.u.Run(t.Context()); err == nil || !strings.Contains(err.Error(), "not an https address") {
		t.Errorf("an http API: %v", err)
	}
}

// GitHub's 403 and 429 read as its rate limit.
func TestRateLimited(t *testing.T) {
	for _, status := range []int{http.StatusForbidden, http.StatusTooManyRequests} {
		f := newFakeGitHub(t)
		f.mu.Lock()
		f.status = status
		f.mu.Unlock()
		r := f.newRun(t, "1.2.9")
		if err := r.u.Run(t.Context()); err == nil || err.Error() != "GitHub is limiting requests from this address; try again later" {
			t.Errorf("%d: %v", status, err)
		}
	}
	f := newFakeGitHub(t)
	f.mu.Lock()
	f.status = http.StatusInternalServerError
	f.mu.Unlock()
	r := f.newRun(t, "1.2.9")
	if err := r.u.Run(t.Context()); err == nil || !strings.Contains(err.Error(), "500 Internal Server Error") {
		t.Errorf("500: %v", err)
	}
}

// What needs no request to refuse is refused before one: a relay not
// built from a release, a system without a release's relay, a bad unit.
func TestRefusesBeforeAsking(t *testing.T) {
	for _, c := range []struct {
		version, goos, goarch, unit, says string
	}{
		{"dev", "linux", "arm64", "", `version is "dev", not a release's`},
		{"", "linux", "arm64", "", "not a release's"},
		{"1.3", "linux", "arm64", "", "not a release's"},
		{"1.3.0-rc.1", "linux", "arm64", "", "not a release's"},
		{"1.3.0-beta.0", "linux", "arm64", "", "not a release's"},
		{"1.2.9", "darwin", "arm64", "", "a release has no relay for darwin/arm64"},
		{"1.2.9", "linux", "386", "", "a release has no relay for linux/386"},
		{"1.2.9", "linux", "arm64", "nushi relay", "a unit's name has only"},
		{"1.2.9", "linux", "arm64", "--now", "a unit's name has only"},
		{"1.2.9", "linux", "arm64", "a;reboot", "a unit's name has only"},
	} {
		f := newFakeGitHub(t)
		f.publish(t, "v1.3.0", false, false, releaseFiles(t))
		r := f.newRun(t, c.version)
		r.u.GOOS, r.u.GOARCH, r.u.Unit = c.goos, c.goarch, c.unit
		if err := r.u.Run(t.Context()); err == nil || !strings.Contains(err.Error(), c.says) {
			t.Errorf("%+v: %v", c, err)
		}
		if len(f.seen()) != 0 {
			t.Errorf("%+v: asked %v", c, f.seen())
		}
		r.untouched(t)
	}
}

// A folder the update can't write says to run it as root, before it
// downloads anything.
func TestUnwritableFolder(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root writes any folder")
	}
	f := newFakeGitHub(t)
	f.publish(t, "v1.3.0", false, false, releaseFiles(t))
	r := f.newRun(t, "1.2.9")
	dir := filepath.Dir(r.exe)
	testcheck.NoErr(t, os.Chmod(dir, 0o555))
	t.Cleanup(func() { _ = os.Chmod(dir, 0o755) })
	err := r.u.Run(t.Context())
	if err == nil || err.Error() != "can't write "+dir+": run it as root (sudo nushi-relay -update)" {
		t.Errorf("%v", err)
	}
	r.untouched(t)
	if len(f.seen()) != 1 {
		t.Errorf("downloaded %v", f.seen())
	}
}

// A relay reached through a link is updated where the link leads; the
// link stays.
func TestFollowsTheLink(t *testing.T) {
	f := newFakeGitHub(t)
	f.publish(t, "v1.3.0", false, false, releaseFiles(t))
	r := f.newRun(t, "1.2.9")
	link := filepath.Join(t.TempDir(), "nushi-relay")
	testcheck.NoErr(t, os.Symlink(r.exe, link))
	r.u.Exe = link
	testcheck.NoErr(t, r.u.Run(t.Context()))
	if b, _ := os.ReadFile(r.exe); string(b) != "new relay" {
		t.Errorf("installed %q", b)
	}
	if fi, err := os.Lstat(link); err != nil || fi.Mode()&os.ModeSymlink == 0 {
		t.Errorf("the link went: %v", err)
	}
}

// The update has a deadline: a host that never answers ends it.
func TestDeadline(t *testing.T) {
	stuck := httptest.NewTLSServer(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) { <-r.Context().Done() }))
	defer stuck.Close()
	f := newFakeGitHub(t)
	r := f.newRun(t, "1.2.9")
	r.u.API, r.u.Client = stuck.URL, NewClient(stuck.Client().Transport)
	r.u.Timeout = 50 * time.Millisecond
	if err := r.u.Run(t.Context()); !errors.Is(err, context.DeadlineExceeded) {
		t.Errorf("%v", err)
	}
}
