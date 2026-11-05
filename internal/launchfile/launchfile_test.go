package launchfile

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// folder is a temp project folder (its real path) with the given files.
func folder(t *testing.T, files map[string]string) string {
	t.Helper()
	dir, err := filepath.EvalSymlinks(t.TempDir())
	testcheck.NoErr(t, err)
	for name, text := range files {
		testcheck.Write(t, filepath.Join(dir, name), text)
	}
	return dir
}

// read is Read of dir with no main checkout, or the test fails.
func read(t *testing.T, dir string) Launch {
	t.Helper()
	l, err := Read(dir, "")
	testcheck.NoErr(t, err)
	return l
}

// yes and no are autoPort's values.
var yes, no = new(true), new(false)

// Claude's documented examples read as Claude reads them.
func TestDocsExamples(t *testing.T) {
	for _, c := range []struct {
		file string
		want []Entry // Source, Hash and Cwd's folder left out
	}{
		{"basic.json", []Entry{{Name: "my-app", Command: "npm", Args: []string{"run", "dev"}, Cwd: ".", Port: 3000}}},
		{"autoverify-off.json", []Entry{{Name: "my-app", Command: "npm", Args: []string{"run", "dev"}, Cwd: ".", Port: 3000}}},
		{"https-url.json", []Entry{{Name: "my-app", Command: "npm", Args: []string{"run", "dev"}, Cwd: ".", Port: 8443, URL: "https://localhost:8443/"}}},
		{"attach.json", []Entry{{Name: "my-app", Port: 3000, URL: "https://app.localhost:3000/"}}},
		{"nextjs.json", []Entry{{Name: "web", Command: "yarn", Args: []string{"dev"}, Cwd: ".", Port: 3000}}},
		{"multiple.json", []Entry{
			{Name: "frontend", Command: "npm", Args: []string{"run", "dev"}, Cwd: "apps/web", Port: 3000, AutoPort: yes},
			{Name: "api", Command: "npm", Args: []string{"run", "start"}, Cwd: "server", Port: 8080, Env: map[string]string{"NODE_ENV": "development"}, AutoPort: no},
		}},
		{"node-script.json", []Entry{{Name: "server", Command: "node", Args: []string{"server.js", "--verbose"}, Cwd: ".", Port: 4000}}},
	} {
		b, err := os.ReadFile(filepath.Join("testdata", "docs", c.file))
		testcheck.NoErr(t, err)
		dir := folder(t, map[string]string{ClaudeFile: string(b), "apps/web/.keep": "", "server/.keep": ""})
		l := read(t, dir)
		if len(l.Files) != 1 || l.Files[0].Err != nil {
			t.Errorf("%s: files %+v", c.file, l.Files)
		}
		for i := range l.Entries {
			e := &l.Entries[i]
			if e.Hash == "" || e.Source != (Source{Path: ClaudeFile, Index: i}) {
				t.Errorf("%s: entry %d: hash %q, source %+v", c.file, i, e.Hash, e.Source)
			}
			e.Hash, e.Source = "", Source{}
			if e.Cwd != "" {
				rel, err := filepath.Rel(dir, e.Cwd)
				testcheck.NoErr(t, err)
				e.Cwd = rel
			}
		}
		if !reflect.DeepEqual(l.Entries, c.want) {
			t.Errorf("%s:\n got %+v\nwant %+v", c.file, l.Entries, c.want)
		}
	}
}

// Names are merged without case, .agents' winning; .agents' come first,
// then .claude's not named there; a name twice in one file is a problem
// at the second, which stays listed.
func TestMerge(t *testing.T) {
	dir := folder(t, map[string]string{
		AgentsFile: `{"configurations": [
			{"name": "Web", "runtimeExecutable": "pnpm", "runtimeArgs": ["dev"]},
			{"name": "web", "runtimeExecutable": "pnpm", "runtimeArgs": ["start"]},
		]}`,
		ClaudeFile: `{"configurations": [
			{"name": "api", "runtimeExecutable": "go", "runtimeArgs": ["run", "."]},
			{"name": "WEB", "runtimeExecutable": "npm", "runtimeArgs": ["run", "dev"]},
		]}`,
	})
	l := read(t, dir)
	type row struct {
		name, command, path, problem string
		index                        int
	}
	var got []row
	for _, e := range l.Entries {
		got = append(got, row{e.Name, e.Command, e.Source.Path, e.Problem, e.Source.Index})
	}
	want := []row{
		{"Web", "pnpm", AgentsFile, "", 0},
		{"web", "pnpm", AgentsFile, "an entry before it in this file has the same name", 1},
		{"api", "go", ClaudeFile, "", 0},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v\nwant %+v", got, want)
	}
	if l.Entries[1].Hash != "" {
		t.Error("a problem entry has a hash")
	}
	if len(l.Files) != 2 || l.Files[0].Path != AgentsFile || l.Files[1].Path != ClaudeFile {
		t.Errorf("files %+v", l.Files)
	}
}

// A worktree with neither file reads the main checkout's, resolved in the
// worktree; one with either file reads only its own.
func TestMainCheckout(t *testing.T) {
	main := folder(t, map[string]string{
		ClaudeFile:    `{"configurations": [{"name": "web", "runtimeExecutable": "${workspaceFolder}/bin/serve", "cwd": "${workspaceFolder}/apps/web"}]}`,
		"apps/web/.k": "",
	})
	tree := folder(t, map[string]string{"apps/web/.k": ""})
	l, err := Read(tree, main)
	testcheck.NoErr(t, err)
	if len(l.Entries) != 1 || len(l.Files) != 1 || !l.Files[0].FromMain {
		t.Fatalf("got %+v", l)
	}
	e := l.Entries[0]
	if e.Command != tree+"/bin/serve" || e.Cwd != tree+"/apps/web" || e.Source != (Source{Path: ClaudeFile, FromMain: true}) || e.Problem != "" {
		t.Errorf("entry %+v", e)
	}

	testcheck.Write(t, filepath.Join(tree, AgentsFile), `{"configurations": []}`)
	l, err = Read(tree, main)
	testcheck.NoErr(t, err)
	if len(l.Entries) != 0 || len(l.Files) != 1 || l.Files[0].FromMain {
		t.Errorf("with its own file: %+v", l)
	}
	if _, err := Read(tree, filepath.Join(main, "gone")); err != nil {
		t.Errorf("a main checkout that's gone: %v", err)
	}
}

// A launch file reached through a link out of the folder is refused,
// and a link inside it followed.
func TestLinks(t *testing.T) {
	outside := folder(t, map[string]string{"launch.json": `{"configurations": [{"name": "x", "program": "a.js"}]}`})
	dir := folder(t, map[string]string{"shared/launch.json": `{"configurations": [{"name": "web", "program": "a.js"}]}`})
	testcheck.NoErr(t, os.Symlink(outside, filepath.Join(dir, ".agents")))
	testcheck.NoErr(t, os.Symlink("shared", filepath.Join(dir, ".claude")))
	l := read(t, dir)
	if len(l.Files) != 2 || l.Files[0].Path != AgentsFile || l.Files[0].Err == nil || l.Files[1].Err != nil {
		t.Fatalf("files %+v", l.Files)
	}
	if len(l.Entries) != 1 || l.Entries[0].Name != "web" || l.Entries[0].Source.Path != ClaudeFile {
		t.Errorf("entries %+v", l.Entries)
	}
	testcheck.NoErr(t, os.Remove(filepath.Join(dir, ".agents")))
	testcheck.NoErr(t, os.Symlink(filepath.Join(outside, "launch.json"), filepath.Join(dir, "shared", "out.json")))
	testcheck.NoErr(t, os.Mkdir(filepath.Join(dir, ".agents"), 0o700))
	testcheck.NoErr(t, os.Symlink("../shared/out.json", filepath.Join(dir, AgentsFile)))
	if l := read(t, dir); len(l.Files) != 2 || l.Files[0].Err == nil || len(l.Entries) != 1 {
		t.Errorf("a file linked out: %+v", l)
	}
}

// What keeps a file from being read is its error, with nothing listed;
// comments and trailing commas are JSON with comments.
func TestFiles(t *testing.T) {
	for _, c := range []struct {
		text, err string
		entries   int
	}{
		{"// servers\n{\"configurations\": [/* one */ {\"name\": \"a\", \"program\": \"a.js\"},],}", "", 1},
		{`{"version": "0.0.1"}`, "", 0},
		{`{"configurations": "web"}`, `"configurations" must be a list`, 0},
		{`{"configurations": null}`, `"configurations" must be a list`, 0},
		{`[]`, "not a JSON object", 0},
		{`null`, "not a JSON object", 0},
		{`{"configurations": [`, "not JSON with comments", 0},
	} {
		l := read(t, folder(t, map[string]string{ClaudeFile: c.text}))
		var err string
		if l.Files[0].Err != nil {
			err = l.Files[0].Err.Error()
		}
		if (c.err == "") != (err == "") || !strings.Contains(err, c.err) || len(l.Entries) != c.entries {
			t.Errorf("%q: err %q, %d entries; want %q, %d", c.text, err, len(l.Entries), c.err, c.entries)
		}
	}
	big := folder(t, map[string]string{ClaudeFile: `{"x": "` + strings.Repeat("a", maxFile) + `"}`})
	if l := read(t, big); l.Files[0].Err == nil {
		t.Error("a file over the most read")
	}
	if l := read(t, folder(t, nil)); len(l.Files) != 0 || len(l.Entries) != 0 {
		t.Errorf("no files: %+v", l)
	}
	if _, err := Read("relative", ""); err == nil {
		t.Error("a relative folder read")
	}
}
