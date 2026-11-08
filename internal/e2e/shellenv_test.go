package e2e

import (
	"context"
	"io/fs"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/encoding/protojson"

	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/codex"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/omp"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/store"
)

// An agent's process starts with a variable only the login shell sets,
// is found on the shell's PATH only, and gets none of Nushi's own
// variables; Codex's adapter gets its CLI on top (ADR 0048).
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
{ env | cut -d= -f1; echo "ONLY_IN_SHELL=$ONLY_IN_SHELL"; echo "CODEX_PATH=$CODEX_PATH"; } > "` + out + `/$(basename "$0").tmp"
mv "` + out + `/$(basename "$0").tmp" "` + out + `/$(basename "$0")"
`
	for _, name := range []string{"omp", "bun", "node", "codex"} {
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
		{Name: "codex", Title: "Codex", CLI: "codex", Adapter: &agents.Adapter{Lock: os.DirFS(t.TempDir()), Package: "p", Bin: "b"}},
	}, agents.Run(env.Environ), env, t.TempDir(), setUp{})
	svc.UseChats(noChats{})

	found := svc.List(context.Background())
	if found[0].Path != filepath.Join(bin, "omp") || found[0].Version != "18.12.6" || !found[0].Ready {
		t.Errorf("omp found: %+v", found[0])
	}
	r, err := svc.Run("omp")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := (omp.Harness{}).Start(t.TempDir(), r, nil, nil); err != nil {
		t.Fatal(err)
	}
	r, err = svc.Run("codex")
	if err != nil {
		t.Fatal(err)
	}
	r.Program = "adapter.js"
	if _, err := (codex.Harness{}).Start(t.TempDir(), r, nil, nil); err != nil {
		t.Fatal(err)
	}
	for name, want := range map[string]string{"omp": "", "node": filepath.Join(bin, "codex")} {
		path, got := filepath.Join(out, name), ""
		until(t, path, func() bool { b, err := os.ReadFile(path); got = string(b); return err == nil })
		if !strings.Contains(got, "\nONLY_IN_SHELL=yes\n") || !strings.Contains(got, "\nCODEX_PATH="+want+"\n") {
			t.Errorf("%s started with:\n%s", name, got)
		}
		if strings.Contains(got, "NUSHI") {
			t.Errorf("%s got Nushi's own variables:\n%s", name, got)
		}
	}
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

// Settings › Agents asks how reading the shell went: the shell, when, and
// why it failed; nothing of the environment reaches the app. A plain list
// doesn't read it again.
func TestTheAppGetsNothingOfTheEnvironment(t *testing.T) {
	shell := filepath.Join(t.TempDir(), "zsh")
	if err := os.WriteFile(shell, []byte("#!/bin/sh\nexport SECRETISH=shell-only-value-31337\nexec /bin/sh -c \"$4\"\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	env := shellenv.New(shell, []string{"PATH=/usr/bin:/bin", "HOME=" + t.TempDir()})
	env.Start()
	agentSvc := agents.New([]agents.Agent{{Name: "fake", Title: "Fake", CLI: "sh"}},
		func(context.Context, string, ...string) ([]byte, error) { return nil, nil }, env, t.TempDir(), setUp{})
	data := t.TempDir()
	st := store.New(data)
	svc := chats.New(t.Context(), []chats.Kind{{Harness: model.HarnessInfo{Name: "fake", Title: "Fake"}}}, chats.Options{Remembered: st, Sessions: st, Worktrees: git.Worktrees{}, Scratch: filepath.Join(data, "scratch")})
	agentSvc.UseChats(svc)
	srv := httptest.NewServer(api.WithToken("tok", api.New(api.Services{Chats: svc, Agents: agentSvc, Transcripts: st})))
	defer srv.Close()
	c := nushiv1connect.NewNushiServiceClient(&http.Client{Transport: bearer{}}, srv.URL)
	ctx := context.Background()

	if got := must(c.ListAgents(ctx, connect.NewRequest(&nushiv1.ListAgentsRequest{}))).Environment; got != nil {
		t.Errorf("a plain list: %v", got)
	}
	read := env.Status().Read
	resp := must(c.ListAgents(ctx, connect.NewRequest(&nushiv1.ListAgentsRequest{ReloadEnvironment: true})))
	if e := resp.Environment; e.GetShell() != shell || e.GetProblem() != "" || e.GetReadUnixMs() <= read.UnixMilli() {
		t.Errorf("reloaded: %v", e)
	}
	if b, _ := protojson.Marshal(resp); strings.Contains(string(b), "31337") || strings.Contains(string(b), "SECRETISH") {
		t.Errorf("the environment reached the app: %s", b)
	}
}
