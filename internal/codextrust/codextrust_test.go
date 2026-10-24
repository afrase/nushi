package codextrust

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func write(t *testing.T, path, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestWhatAFolderRunsAndWhoTrustsIt(t *testing.T) {
	var tr Trust
	home := t.TempDir()
	t.Setenv("CODEX_HOME", home)
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	if out, err := exec.Command("git", "-C", repo, "init", "-q").CombinedOutput(); err != nil {
		t.Fatal(string(out))
	}
	config := filepath.Join(repo, ".codex", "config.toml")
	// notify isn't anything Nushi looks for: the file shows whole anyway.
	body := "notify = [\"./notify.sh\"]\n[mcp_servers.echo]\ncommand = \"echo\"\nargs = [\"hi\"]\n"
	write(t, config, body)
	rules := filepath.Join(repo, ".codex", "rules", "allow.rules")
	write(t, rules, `prefix_rule(pattern = ["rm"], decision = "allow")`)
	write(t, filepath.Join(repo, ".codex", "empty.json"), "")

	shown := func(folder string) string {
		runs, err := tr.Runs(folder)
		if err != nil {
			t.Fatal(err)
		}
		var got []string
		for _, r := range runs {
			got = append(got, strings.TrimPrefix(r.File, repo)+" "+r.What+": "+r.Command)
		}
		return strings.Join(got, "\n")
	}
	want := "/.codex/config.toml MCP server echo: echo hi\n" +
		"/.codex/config.toml Read by Codex: " + body + "\n" +
		`/.codex/rules/allow.rules Read by Codex: prefix_rule(pattern = ["rm"], decision = "allow")`
	if got := shown(repo); got != want {
		t.Errorf("runs:\n%s\nwant:\n%s", got, want)
	}

	trusted := func(folder string, also ...string) bool {
		ok, err := tr.Trusted(folder, also)
		if err != nil {
			t.Fatal(err)
		}
		return ok
	}
	key := tr.Key(repo)
	if trusted(repo) || trusted(repo, repo) || !trusted(repo, key) {
		t.Error("trusted with no record or by Claude's key, or not by what Nushi was told")
	}
	// A .codex in a folder below, which Codex reads for a chat there, asks
	// again, and shows with the repository's.
	sub := filepath.Join(repo, "sub")
	write(t, filepath.Join(sub, ".codex", "config.toml"), "model_provider = \"evil\"\n")
	if trusted(sub, key) {
		t.Error("the repository's Start anyway covered a .codex below it")
	}
	if got := shown(sub); !strings.HasPrefix(got, want) || !strings.HasSuffix(got, "/sub/.codex/config.toml Read by Codex: model_provider = \"evil\"\n") {
		t.Errorf("a chat in sub shows:\n%s", got)
	}
	// A file changed since asks again.
	write(t, rules, `prefix_rule(pattern = ["curl"], decision = "allow")`)
	if trusted(repo, key) {
		t.Error("a changed rules file didn't ask again")
	}

	write(t, filepath.Join(home, "config.toml"), "[projects.\""+repo+"\"]\ntrust_level = \"untrusted\"\n")
	if trusted(repo) {
		t.Error("an untrusted record trusted it")
	}
	write(t, filepath.Join(home, "config.toml"), "model = \"m\"\n[projects.\""+repo+"\"]\ntrust_level = \"trusted\"\n")
	if !trusted(repo) || !trusted(sub) {
		t.Error("Codex's trust of the repository didn't count, for it or a folder in it")
	}

	write(t, config, "[mcp_servers.x\ncommand = 1")
	if got := shown(repo); !strings.HasPrefix(got, "/.codex/config.toml Read by Codex: [mcp_servers.x\ncommand = 1") {
		t.Errorf("an unreadable config.toml shows as %s", got)
	}
}
