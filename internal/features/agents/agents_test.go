package agents

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"testing/fstest"

	"github.com/afrase/nushi/internal/readonly"
	"github.com/afrase/nushi/internal/testcheck"
)

// fakeCLI writes a program into dir that prints out for --version and
// tries to leave a file behind.
func fakeCLI(t *testing.T, dir, name, out string) string {
	t.Helper()
	p := filepath.Join(dir, name)
	script := "#!/bin/sh\ntouch " + filepath.Join(dir, name+".wrote") + " 2>/dev/null\n" +
		"[ \"$1\" = auth ] && { echo '{\"loggedIn\": true}'; exit 0; }\nprintf '%s' '" + out + "'\n"
	if err := os.WriteFile(p, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return p
}

// Agents found on a PATH of fakes: installed with a version, missing,
// odd version output, found off PATH, too old, missing what they run
// under; and nothing they tried to write was written.
func TestList(t *testing.T) {
	bin, other := t.TempDir(), t.TempDir()
	fakeCLI(t, bin, "claude", "2.1.310 (Claude Code)\n")
	fakeCLI(t, bin, "codex", "codex-cli 0.163.0-alpha.2\nmore\n")
	fakeCLI(t, bin, "odd", "Odd, no version here\n")
	off := fakeCLI(t, other, "ante", "ante 0.2.9")
	fakeCLI(t, bin, "omp", "18.12.6")
	fakeCLI(t, bin, "pig", "0.5.3+1.4.0.74f46864")
	t.Setenv("PATH", bin+":/usr/bin:/bin")
	signedIn := func(run func(...string) ([]byte, error)) string {
		out, err := run("auth", "status")
		if err != nil || !strings.Contains(string(out), `"loggedIn": true`) {
			return "no"
		}
		return "yes"
	}
	svc := newService([]Agent{
		{Name: "claude", CLI: "claude", SignedIn: signedIn},
		{Name: "codex", CLI: "codex"},
		{Name: "odd", CLI: "odd"},
		{Name: "ante", CLI: "ante", Also: []string{filepath.Join(other, "nope"), off}, Min: "0.2.14"},
		{Name: "omp", CLI: "omp", Needs: "bun"},
		{Name: "pig", CLI: "pig"},
		{Name: "gone", CLI: "gone"},
	}, "", &fakeInstaller{}, &fakeChats{})
	want := []Status{
		{Path: bin + "/claude", Version: "2.1.310", SignedIn: "yes"},
		{Path: bin + "/codex", Version: "0.163.0-alpha.2"},
		{Path: bin + "/odd"},
		{Path: off, Version: "0.2.9", Problem: "Needs 0.2.14 or newer"},
		{Path: bin + "/omp", Version: "18.12.6", Problem: "Needs Bun"},
		{Path: bin + "/pig", Version: "0.5.3"},
		{Problem: "Not installed"},
	}
	for i, got := range svc.List(context.Background()) {
		w := want[i]
		if got.Path != w.Path || got.Version != w.Version || got.Problem != w.Problem || got.SignedIn != w.SignedIn {
			t.Errorf("%s: %+v, want %+v", got.Name, got, w)
		}
	}
	for _, d := range []string{bin, other} {
		if wrote, _ := filepath.Glob(filepath.Join(d, "*.wrote")); len(wrote) > 0 {
			t.Errorf("a probe wrote %s", wrote)
		}
	}
}

func TestOlder(t *testing.T) {
	for _, c := range []struct {
		a, b string
		want bool
	}{{"0.2.9", "0.2.14", true}, {"0.2.14", "0.2.14", false}, {"1.0", "0.9.9", false}, {"0.2.14-rc1", "0.2.15", true}, {"2.1", "2.1.1", true}} {
		if older(c.a, c.b) != c.want {
			t.Errorf("older(%s, %s) isn't %v", c.a, c.b, c.want)
		}
	}
}

// newService finds agents with readonly.Output.
func newService(agents []Agent, dir string, in Installer, chats Chats) *Service {
	s := New(agents, func(ctx context.Context, path string, args ...string) ([]byte, error) {
		return readonly.Output(ctx, nil, path, args...)
	}, dir, in)
	s.UseChats(chats)
	return s
}

type fakeChats struct {
	awake, slept int
	ready        []string // the agents it was told are ready, in order
}

func (f *fakeChats) Awake(string) int { return f.awake }

func (f *fakeChats) SleepAgent(string) { f.slept, f.awake = f.slept+f.awake, 0 }

func (f *fakeChats) AgentReady(agent string) { f.ready = append(f.ready, agent) }

// fakeInstaller installs a version: "1.0.0" without fail.
type fakeInstaller struct {
	versions map[string]string // by folder
	fail     bool
}

func (f *fakeInstaller) Install(_ context.Context, _ fs.FS, folder string, ready func()) error {
	if f.fail {
		return errors.New("npm ci: no network")
	}
	ready()
	f.versions = map[string]string{folder: "1.0.0"}
	return nil
}

func (f *fakeInstaller) Installed(folder, _, bin string) (string, string) {
	if v := f.versions[folder]; v != "" {
		return v, filepath.Join(folder, bin)
	}
	return "", ""
}

func (f *fakeInstaller) Remove(folder string) error { delete(f.versions, folder); return nil }

// An agent with an adapter: not ready until it's set up; setting it up
// puts its awake chats to sleep, and tells the chats it's ready; a failed
// install says why; Remove; found ready (Node back), the chats are told.
func TestSetUp(t *testing.T) {
	bin := t.TempDir()
	fakeCLI(t, bin, "claude", "2.1.310")
	fakeCLI(t, bin, "node", "v26.1.0")
	fakeCLI(t, bin, "npm", "11.13.0")
	t.Setenv("PATH", bin+":/usr/bin:/bin")
	lock := fstest.MapFS{
		"package.json":      {Data: []byte(`{"dependencies":{"adapter":"1.0.0"}}`)},
		"package-lock.json": {Data: []byte(`{"packages":{"":{},"node_modules/adapter":{},"node_modules/dep":{},"node_modules/bin-darwin":{"optional":true}}}`)},
	}
	chats, in := &fakeChats{awake: 2}, &fakeInstaller{}
	dir := t.TempDir()
	svc := newService([]Agent{{Name: "claude", Title: "Claude", CLI: "claude", Adapter: &Adapter{Lock: lock, Package: "adapter", Bin: "adapter"}}, {Name: "ante", Title: "Ante", CLI: "ante"}},
		dir, in, chats)
	st := svc.List(context.Background())[0]
	if st.Ready || st.Pinned != "1.0.0" || st.Packages != 2 || st.Installed != "" || st.Folder != filepath.Join(dir, "claude") || st.Awake != 2 {
		t.Fatalf("before: %+v", st)
	}
	if _, err := svc.Run("claude"); err == nil || err.Error() != "Claude isn't set up: Settings › Agents" {
		t.Errorf("Run before SetUp: %v", err)
	}
	in.fail = true
	if err := svc.SetUp(context.Background(), "claude"); err == nil || chats.slept != 0 || chats.ready != nil {
		t.Errorf("a failed install: %v, %d slept, ready %q", err, chats.slept, chats.ready)
	}
	in.fail = false
	if err := svc.SetUp(context.Background(), "claude"); err != nil || chats.slept != 2 || !slices.Equal(chats.ready, []string{"claude"}) {
		t.Fatalf("SetUp: %v, %d slept, ready %q", err, chats.slept, chats.ready)
	}
	if st := svc.List(context.Background())[0]; !st.Ready || st.Installed != "1.0.0" || st.Program != filepath.Join(dir, "claude", "adapter") {
		t.Errorf("after: %+v", st)
	}
	if r, err := svc.Run("claude"); err != nil || r.CLI != filepath.Join(bin, "claude") || r.Program != filepath.Join(dir, "claude", "adapter") {
		t.Errorf("Run: %+v, %v", r, err)
	}
	if _, err := svc.Run("ante"); err == nil || err.Error() != "Ante isn't installed: there's no ante on PATH" {
		t.Errorf("Run without its CLI: %v", err)
	}
	if err := svc.SetUp(context.Background(), "ante"); err == nil {
		t.Error("set up an agent without an adapter")
	}
	if err := svc.Remove("claude"); err != nil || svc.List(context.Background())[0].Ready {
		t.Errorf("Remove: %v", err)
	}
	testcheck.NoErr(t, os.Remove(filepath.Join(bin, "node")))
	in.versions = map[string]string{filepath.Join(dir, "claude"): "1.0.0"}
	if st := svc.List(context.Background())[0]; st.Problem != "Needs Node" || st.Ready {
		t.Errorf("without Node: %+v", st)
	}
	if _, err := svc.Run("claude"); err == nil {
		t.Error("Run without Node")
	}
	chats.ready = nil
	fakeCLI(t, bin, "node", "v26.1.0")
	svc.List(context.Background())
	if !slices.Equal(chats.ready, []string{"claude"}) {
		t.Errorf("found ready again: told %q", chats.ready)
	}
}

// A failed start of a CLI version Nushi wasn't tested with says which it
// was tested with; a tested one, or one that isn't set up, doesn't.
func TestExplain(t *testing.T) {
	bin := t.TempDir()
	fakeCLI(t, bin, "codex", "codex-cli 0.170.0")
	fakeCLI(t, bin, "ante", "ante 0.2.14")
	t.Setenv("PATH", bin+":/usr/bin:/bin")
	svc := newService([]Agent{{Name: "codex", Title: "Codex", CLI: "codex", Tested: []string{"0.160.1", "0.163.0"}}, {Name: "ante", Title: "Ante", CLI: "ante", Tested: []string{"0.2.14"}},
		{Name: "claude", Title: "Claude", CLI: "claude", Tested: []string{"2.1.310"}}}, "", &fakeInstaller{}, &fakeChats{})
	failed := errors.New("initialize: it quit")
	for name, want := range map[string]string{
		"codex":  "initialize: it quit (Nushi was tested with Codex 0.160.1 and 0.163.0; this is 0.170.0)",
		"ante":   "initialize: it quit",
		"claude": "initialize: it quit",
	} {
		if got := svc.Explain(name)(failed); got.Error() != want || !errors.Is(got, failed) {
			t.Errorf("%s: %v", name, got)
		}
	}
}
