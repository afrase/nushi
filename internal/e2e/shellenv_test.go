package e2e

import (
	"context"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/omp"
	"github.com/afrase/nushi/internal/readonly"
	"github.com/afrase/nushi/internal/shellenv"
)

// An agent's process starts with a variable only the login shell sets,
// is found on the shell's PATH only, and gets none of Nushi's own
// variables; Claude's adapter gets its CLI on top (ADR 0048).
func TestAgentsStartWithTheShellsEnvironment(t *testing.T) {
	bin, out := t.TempDir(), t.TempDir()
	write := func(path, body string) {
		t.Helper()
		if err := os.WriteFile(path, []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	// Each program writes what it was started with: the names of its
	// environment, and the values of the few this test looks at.
	report := `[ "$1" = --version ] && { echo 18.12.6; exit 0; }
{ env | cut -d= -f1; echo "ONLY_IN_SHELL=$ONLY_IN_SHELL"; echo "CLAUDE_CODE_EXECUTABLE=$CLAUDE_CODE_EXECUTABLE"; } > "` + out + `/$(basename "$0").tmp"
mv "` + out + `/$(basename "$0").tmp" "` + out + `/$(basename "$0")"
`
	for _, name := range []string{"omp", "bun", "node", "claude"} {
		write(filepath.Join(bin, name), "#!/bin/sh\n"+report)
	}
	shell := filepath.Join(t.TempDir(), "fish")
	write(shell, `#!/bin/sh
echo "a config that talks"
export ONLY_IN_SHELL=yes PATH="`+bin+`:$PATH"
exec /bin/sh -c "$4"
`)
	env := shellenv.New(shell, []string{"PATH=/usr/bin:/bin", "HOME=" + t.TempDir(), "NUSHI_DATA=/data", "NUSHI_TOOLS_KEY=not-for-agents", "NUSHID_LOG=/l"})
	env.Start()
	svc := agents.New([]agents.Agent{
		{Name: "omp", Title: "oh-my-pi", CLI: "omp", Needs: "bun"},
		{Name: "claude", Title: "Claude", CLI: "claude", Adapter: &agents.Adapter{Lock: os.DirFS(t.TempDir()), Package: "p", Bin: "b"}},
	}, func(ctx context.Context, path string, args ...string) ([]byte, error) {
		return readonly.Output(ctx, env.Environ(), path, args...)
	}, t.TempDir(), setUp{})
	svc.UseEnv(env)
	svc.UseChats(noChats{})

	found := svc.List(context.Background())
	if found[0].Path != filepath.Join(bin, "omp") || found[0].Version != "18.12.6" || !found[0].Ready {
		t.Errorf("omp found: %+v", found[0])
	}
	r, err := svc.Run("omp")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := omp.Start(t.TempDir(), r.CLI, r.Env, nil, nil); err != nil {
		t.Fatal(err)
	}
	r, err = svc.Run("claude")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := claude.Start(t.TempDir(), r.Node, "adapter.js", r.CLI, r.Env, nil, nil); err != nil {
		t.Fatal(err)
	}
	for name, want := range map[string]string{"omp": "", "node": filepath.Join(bin, "claude")} {
		got := waitFor(t, filepath.Join(out, name))
		if !strings.Contains(got, "\nONLY_IN_SHELL=yes\n") || !strings.Contains(got, "\nCLAUDE_CODE_EXECUTABLE="+want+"\n") {
			t.Errorf("%s started with:\n%s", name, got)
		}
		if strings.Contains(got, "NUSHI") {
			t.Errorf("%s got Nushi's own variables:\n%s", name, got)
		}
	}
}

func waitFor(t *testing.T, path string) string {
	t.Helper()
	for range 100 {
		if b, err := os.ReadFile(path); err == nil {
			return string(b)
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("%s never came", path)
	return ""
}

// setUp has every adapter set up.
type setUp struct{}

func (setUp) Install(context.Context, fs.FS, string, func()) error { return nil }
func (setUp) Installed(folder, _, bin string) (string, string) {
	return "1.0.0", filepath.Join(folder, bin)
}
func (setUp) Remove(string) error { return nil }

type noChats struct{}

func (noChats) Awake(string) int  { return 0 }
func (noChats) SleepAgent(string) {}
func (noChats) AgentReady(string) {}
