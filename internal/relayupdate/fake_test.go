package relayupdate

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// fakeGitHub plays GitHub's API and its download host, over TLS: the
// API's asset addresses redirect to the download host, as GitHub's do.
type fakeGitHub struct {
	api, files *httptest.Server

	mu       sync.Mutex
	latest   []byte            // the API's answer
	status   int               // the API's status, 0: 200
	served   map[string][]byte // the download host's files by name
	lies     map[string]int    // a Content-Length to claim instead, by name
	endless  map[string]bool   // sent chunked, with no Content-Length, and never ending, by name
	redirect map[string]string // a download's address to send to instead of the host's, by name
	requests []string          // every request's path, both hosts
	agents   []string          // every request's User-Agent
}

func newFakeGitHub(t *testing.T) *fakeGitHub {
	t.Helper()
	f := &fakeGitHub{served: map[string][]byte{}, lies: map[string]int{}, endless: map[string]bool{}, redirect: map[string]string{}}
	f.api = httptest.NewTLSServer(http.HandlerFunc(f.serveAPI))
	t.Cleanup(f.api.Close)
	f.files = httptest.NewTLSServer(http.HandlerFunc(f.serveFile))
	t.Cleanup(f.files.Close)
	return f
}

func (f *fakeGitHub) note(r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.requests = append(f.requests, r.URL.Path)
	f.agents = append(f.agents, r.UserAgent())
}

func (f *fakeGitHub) serveAPI(w http.ResponseWriter, r *http.Request) {
	f.note(r)
	f.mu.Lock()
	defer f.mu.Unlock()
	if name, ok := strings.CutPrefix(r.URL.Path, "/download/"); ok {
		to := f.files.URL + "/files/" + name
		if alt, ok := f.redirect[name]; ok {
			to = alt
		}
		http.Redirect(w, r, to, http.StatusFound) //nolint:gosec // the fake GitHub sends a download to its own hosts
		return
	}
	if r.URL.Path != "/repos/"+Repo+"/releases/latest" {
		http.NotFound(w, r)
		return
	}
	if f.status != 0 {
		w.WriteHeader(f.status)
		return
	}
	_, _ = w.Write(f.latest)
}

func (f *fakeGitHub) serveFile(w http.ResponseWriter, r *http.Request) {
	f.note(r)
	f.mu.Lock()
	name := strings.TrimPrefix(r.URL.Path, "/files/")
	body, ok := f.served[name]
	lie, lies := f.lies[name]
	endless := f.endless[name]
	f.mu.Unlock()
	if !ok {
		http.NotFound(w, r)
		return
	}
	if lies {
		w.Header().Set("Content-Length", strconv.Itoa(lie))
	}
	_, _ = w.Write(body)
	if endless {
		// Flushed before the end, the body goes chunked, with no
		// Content-Length for the client to refuse early, and it never
		// ends: only the client's read cap stops it, closing the
		// connection, which ends this loop.
		rc := http.NewResponseController(w)
		more := make([]byte, 4096)
		for rc.Flush() == nil {
			if _, err := w.Write(more); err != nil {
				return
			}
		}
	}
}

// publish makes tag the latest release, with these files attached (the
// download host serves them) and its draft and pre-release flags.
func (f *fakeGitHub) publish(t *testing.T, tag string, draft, pre bool, files map[string][]byte) {
	t.Helper()
	type a struct {
		Name string `json:"name"`
		URL  string `json:"browser_download_url"`
		Size int    `json:"size"`
	}
	rel := struct {
		Tag        string `json:"tag_name"`
		Draft      bool   `json:"draft"`
		Prerelease bool   `json:"prerelease"`
		Assets     []a    `json:"assets"`
	}{Tag: tag, Draft: draft, Prerelease: pre, Assets: []a{}}
	f.mu.Lock()
	defer f.mu.Unlock()
	for name, body := range files {
		rel.Assets = append(rel.Assets, a{Name: name, URL: f.api.URL + "/download/" + name, Size: len(body)})
		f.served[name] = body
	}
	f.latest = []byte(testcheck.JSON(t, rel))
}

// seen is every request's path so far.
func (f *fakeGitHub) seen() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.requests...)
}

// entry is one file in a tarball.
type entry struct {
	name string
	body string
	kind byte // tar.TypeReg unless set
	link string
}

// tarball is a gzipped tar of entries, as tools/release.sh writes one.
func tarball(t *testing.T, entries ...entry) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := gzip.NewWriter(&buf)
	tw := tar.NewWriter(zw)
	for _, e := range entries {
		hdr := &tar.Header{Name: e.name, Mode: 0o755, Size: int64(len(e.body)), Typeflag: tar.TypeReg, Linkname: e.link}
		if e.kind != 0 {
			hdr.Typeflag, hdr.Size = e.kind, 0
		}
		testcheck.NoErr(t, tw.WriteHeader(hdr))
		_, err := tw.Write([]byte(e.body))
		testcheck.NoErr(t, err)
	}
	testcheck.NoErr(t, tw.Close())
	testcheck.NoErr(t, zw.Close())
	return buf.Bytes()
}

// tarName is the release's tarball for linux/arm64 the tests publish.
const tarName = "nushi-relay-1.3.0-linux-arm64.tar.gz"

// sumOf is tarName's .sha256 for b as `shasum -a 256` writes it.
func sumOf(b []byte) []byte {
	return fmt.Appendf(nil, "%x  %s\n", sha256.Sum256(b), tarName)
}

// releaseFiles is release 1.3.0's tarball and .sha256 for linux/arm64,
// holding a relay whose bytes are "new relay".
func releaseFiles(t *testing.T) map[string][]byte {
	t.Helper()
	tb := tarball(t, entry{name: "nushi-relay", body: "new relay"})
	return map[string][]byte{tarName: tb, tarName + ".sha256": sumOf(tb)}
}

// run is a test's update: an installed relay at version in a temp folder
// (mode 0751, bytes "old relay"), linux/arm64, a verifier that accepts
// and a restart that records.
type run struct {
	u        *Updater
	exe      string
	out      bytes.Buffer
	verified []string // the files the verifier was asked about
	restarts []string
}

func (f *fakeGitHub) newRun(t *testing.T, version string) *run {
	t.Helper()
	tmp, err := filepath.EvalSymlinks(t.TempDir()) // macOS's temp folder is behind /var's link
	testcheck.NoErr(t, err)
	r := &run{exe: filepath.Join(tmp, "bin", "nushi-relay")}
	testcheck.NoErr(t, os.MkdirAll(filepath.Dir(r.exe), 0o755))
	testcheck.NoErr(t, os.WriteFile(r.exe, []byte("old relay"), 0o600))
	testcheck.NoErr(t, os.Chmod(r.exe, 0o751))
	r.u = New(version, "", &r.out)
	r.u.API = f.api.URL
	r.u.Client = NewClient(f.api.Client().Transport)
	r.u.Exe = r.exe
	r.u.GOOS, r.u.GOARCH = "linux", "arm64"
	r.u.Verify = func(_ context.Context, path string) error {
		if filepath.Dir(path) != filepath.Dir(r.exe) {
			t.Errorf("verified %s, not beside %s", path, r.exe)
		}
		r.verified = append(r.verified, path)
		return nil
	}
	r.u.Restart = func(_ context.Context, unit string) error {
		r.restarts = append(r.restarts, unit)
		return nil
	}
	return r
}

// lines is what the run printed, a line each.
func (r *run) lines() []string {
	return strings.Split(strings.TrimSuffix(r.out.String(), "\n"), "\n")
}

// untouched fails unless the installed relay is as it was and nothing is
// left beside it.
func (r *run) untouched(t *testing.T) {
	t.Helper()
	b, err := os.ReadFile(r.exe)
	testcheck.NoErr(t, err)
	if string(b) != "old relay" {
		t.Errorf("the installed relay is %q", b)
	}
	r.alone(t)
}

// alone fails if anything but the relay is in its folder.
func (r *run) alone(t *testing.T) {
	t.Helper()
	files, err := os.ReadDir(filepath.Dir(r.exe))
	testcheck.NoErr(t, err)
	if len(files) != 1 {
		names := []string{}
		for _, f := range files {
			names = append(names, f.Name())
		}
		t.Errorf("the folder holds %v", names)
	}
}
