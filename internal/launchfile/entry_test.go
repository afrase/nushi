package launchfile

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// project is a temp folder (its real path) with a web folder, open as a
// place.
func project(t *testing.T) place {
	t.Helper()
	dir, err := filepath.EvalSymlinks(t.TempDir())
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, os.Mkdir(filepath.Join(dir, "web"), 0o700))
	root, err := os.OpenRoot(dir)
	testcheck.NoErr(t, err)
	t.Cleanup(func() { root.Close() }) //nolint:errcheck // read-only
	return place{folder: dir, root: root}
}

// Entries Claude refuses have a problem naming the key, and no hash.
func TestProblems(t *testing.T) {
	p := project(t)
	for _, c := range []struct{ configuration, problem string }{
		{`{"name": "build", "type": "node-terminal", "command": "npm run dev"}`, `VS Code "command"`},
		{`{"name": "task", "command": "npm run dev"}`, `VS Code "command"`},
		{`{"name": "debug", "type": "node", "request": "launch", "url": "http://localhost:3000"}`, `VS Code "command"`},
		{`{"name": "nothing"}`, `needs "runtimeExecutable"`},
		{`{"name": "nothing", "env": {"PORT": "3000"}}`, `needs "runtimeExecutable"`},
		{`"npm run dev"`, "not a JSON object"},
		{`{"name": 5, "program": "a.js"}`, `"name" must be a string`},
		{`{"name": "a", "program": "a.js", "autoPort": "true"}`, `"autoPort" must be true or false`},
		{`{"name": "a", "program": "a.js", "port": 70000}`, `"port" must be`},
		{`{"name": "a", "program": "a.js", "args": ["--port", "99999"]}`, "isn't from 1 to 65535"},
		{`{"name": "a", "program": "a.js", "env": {"PORT": "-5"}}`, "isn't from 1 to 65535"},
		{`{"name": "a", "url": null}`, `"url" must be a non-empty string`},
		{`{"name": "a", "url": 3000}`, `"url" must be a non-empty string`},
		{`{"name": "a", "url": " "}`, `"url" must be a non-empty string`},
		{`{"name": "a", "url": "http://localhost:3000/admin"}`, "the server's origin alone"},
		{`{"name": "a", "program": "a.js", "port": 3000, "url": "http://localhost:4000"}`, "another port than the entry's"},
		{`{"name": "a", "program": "a.js", "port": 3000, "url": "https://localhost"}`, "another port than the entry's"},
		{`{"name": "a", "program": "a.js", "cwd": "../x"}`, `"cwd" must be a folder inside`},
	} {
		e := p.entry(json.RawMessage(c.configuration))
		if !strings.Contains(e.Problem, c.problem) || e.Hash != "" {
			t.Errorf("%s: problem %q, want %q", c.configuration, e.Problem, c.problem)
		}
	}
	if e := p.entry(json.RawMessage(`{"name": "Web", "port": "x", "program": "a.js"}`)); e.Name != "Web" {
		t.Errorf("a refused entry's name: %q", e.Name)
	}
}

// The port is the entry's, else its localhost url's, else the command's,
// else 3000 with a command.
func TestPorts(t *testing.T) {
	p := project(t)
	for _, c := range []struct {
		configuration string
		port          int
	}{
		{`{"name": "a", "program": "a.js"}`, 3000},
		{`{"name": "a", "program": "a.js", "port": 0, "args": ["--port", "0"]}`, 3000},
		{`{"name": "a", "program": "a.js", "port": 4000, "env": {"PORT": "5000"}}`, 4000},
		{`{"name": "a", "program": "a.js", "url": "http://localhost:4321", "env": {"PORT": "5000"}}`, 4321},
		{`{"name": "a", "program": "a.js", "url": "https://localhost"}`, 443},
		{`{"name": "a", "program": "a.js", "url": "http://example.com:9000/app"}`, 3000},
		{`{"name": "a", "program": "a.js", "url": "http://example.com:9000/app", "env": {"PORT": "5000"}}`, 5000},
		{`{"name": "a", "runtimeExecutable": "npx", "runtimeArgs": ["vite", "--port", "5174"]}`, 5174},
		{`{"name": "a", "url": "http://localhost:3000"}`, 3000},
		{`{"name": "a", "url": "https://example.com/app"}`, 0},
		{`{"name": "a", "url": "https://example.com", "env": {"PORT": "4100"}}`, 4100},
	} {
		e := p.entry(json.RawMessage(c.configuration))
		if e.Problem != "" || e.Port != c.port {
			t.Errorf("%s: port %d (%q), want %d", c.configuration, e.Port, e.Problem, c.port)
		}
	}
}

// A name not given is derived as Claude derives it; one that fails
// ValidName is still an entry, to be addressed by its index.
func TestNames(t *testing.T) {
	p := project(t)
	for _, c := range []struct {
		configuration, name string
		derived, valid      bool
	}{
		{`{"runtimeExecutable": "npm", "runtimeArgs": ["run", "dev"]}`, "dev", true, true},
		{`{"name": "", "runtimeExecutable": "npm", "runtimeArgs": ["run", "build:watch"]}`, "build-watch", true, true},
		{`{"program": "server.js"}`, "server", true, true},
		{`{"program": "server.js", "args": ["--verbose"]}`, "--verbose", true, false},
		{`{"program": "a.js"}`, "preview", true, true},
		{`{"runtimeExecutable": "make"}`, "preview", true, true},
		{`{"runtimeExecutable": "node", "runtimeArgs": ["app.min.js"]}`, "app.min", true, true},
		{`{"runtimeExecutable": "node", "runtimeArgs": [".env"]}`, "preview", true, true},
		{`{"url": "http://localhost:3000"}`, "localhost:3000", true, true},
		{`{"url": "https://app.localhost:443"}`, "app.localhost", true, true},
		{`{"url": "http://[::1]:8080"}`, "[::1]:8080", true, false},
		{`{"url": "http://EXAMPLE.com/a"}`, "example.com", true, true},
		{`{"name": "Web App", "program": "a.js"}`, "Web App", false, false},
		{`{"name": "web\u202eppa", "program": "a.js"}`, "web\u202eppa", false, false},
		{`{"name": "-web", "program": "a.js"}`, "-web", false, false},
		{`{"name": "web:dev_2.x-1", "program": "a.js"}`, "web:dev_2.x-1", false, true},
	} {
		e := p.entry(json.RawMessage(c.configuration))
		if e.Problem != "" || e.Name != c.name || e.NameDerived != c.derived || ValidName(e.Name) != c.valid {
			t.Errorf("%s: %q derived %v valid %v (%q); want %q %v %v", c.configuration, e.Name, e.NameDerived, ValidName(e.Name), e.Problem, c.name, c.derived, c.valid)
		}
	}
	if ValidName(strings.Repeat("a", 65)) || !ValidName(strings.Repeat("a", 64)) || ValidName("") {
		t.Error("a name's length")
	}
}

// Variables are the folder in the command, its arguments and cwd, not in
// env; an attach has no command or cwd.
func TestResolve(t *testing.T) {
	p := project(t)
	e := p.entry(json.RawMessage(`{"name": "a", "runtimeExecutable": "${workspaceRoot}/node_modules/.bin/vite",
		"runtimeArgs": ["--config", "${workspaceFolder}/vite.config.ts"], "program": "p.js", "args": ["x"],
		"cwd": "${workspaceFolder}/web/", "env": {"HOME_DIR": "${workspaceFolder}"}, "autoPort": false}`))
	if e.Command != p.folder+"/node_modules/.bin/vite" || strings.Join(e.Args, " ") != "--config "+p.folder+"/vite.config.ts p.js x" ||
		e.Cwd != filepath.Join(p.folder, "web") || e.Env["HOME_DIR"] != "${workspaceFolder}" || e.AutoPort == nil || *e.AutoPort || e.Problem != "" {
		t.Errorf("entry %+v", e)
	}
	e = p.entry(json.RawMessage(`{"name": "a", "url": "HTTP://LocalHost:3000", "cwd": "nowhere"}`))
	if e.Problem != "" || e.URL != "http://localhost:3000/" || e.Command != "" || e.Cwd != "" || e.Args != nil {
		t.Errorf("attach %+v", e)
	}
}

// cwd must be a folder inside the folder, through no link out of it.
func TestCwd(t *testing.T) {
	p := project(t)
	outside := t.TempDir()
	testcheck.NoErr(t, os.Symlink(outside, filepath.Join(p.folder, "out")))
	testcheck.NoErr(t, os.Symlink("web", filepath.Join(p.folder, "in")))
	testcheck.Write(t, filepath.Join(p.folder, "file"), "")
	for cwd, want := range map[string]string{
		"":                      "",
		".":                     "",
		"web":                   "",
		"in":                    "",
		"./web/../web":          "",
		p.folder + "/web":       "",
		"out":                   "through no link out of it",
		"../x":                  "must be a folder inside",
		"web/../../x":           "must be a folder inside",
		"/tmp":                  "must be a folder inside",
		"${workspaceFolder}/..": "must be a folder inside",
		"nowhere":               "names no folder",
		"file":                  "must be a folder",
	} {
		e := p.entry(json.RawMessage(`{"name": "a", "program": "a.js", "cwd": ` + testcheck.JSON(t, cwd) + `}`))
		if got := e.Problem; (want == "") != (got == "") || !strings.Contains(got, want) {
			t.Errorf("%q: problem %q, want %q", cwd, got, want)
		}
		if want == "" && !strings.HasPrefix(e.Cwd, p.folder) {
			t.Errorf("%q: cwd %q", cwd, e.Cwd)
		}
	}
}

// The hash follows what an entry resolves to, not how it is written.
func TestHash(t *testing.T) {
	p := project(t)
	hashOf := func(configuration string) string { return p.entry(json.RawMessage(configuration)).Hash }
	a := hashOf(`{"name": "a", "runtimeExecutable": "npm", "runtimeArgs": ["run", "dev"], "port": 3000}`)
	same := hashOf(`{"runtimeArgs": ["run", "dev"], "port": "3000", "name": "a", "runtimeExecutable": "npm", "cwd": "${workspaceFolder}"}`)
	for _, other := range []string{
		`{"name": "a", "runtimeExecutable": "npm", "runtimeArgs": ["run", "dev"], "port": 3001}`,
		`{"name": "A", "runtimeExecutable": "npm", "runtimeArgs": ["run", "dev"], "port": 3000}`,
		`{"name": "a", "runtimeExecutable": "npm", "runtimeArgs": ["run", "dev"], "port": 3000, "cwd": "web"}`,
		`{"name": "a", "runtimeExecutable": "npm", "runtimeArgs": ["run", "dev"], "port": 3000, "autoPort": true}`,
		`{"name": "a", "runtimeExecutable": "npm", "runtimeArgs": ["run", "dev"], "port": 3000, "env": {"A": ""}}`,
	} {
		if hashOf(other) == a {
			t.Errorf("same hash: %s", other)
		}
	}
	if len(a) != 64 || a != same {
		t.Errorf("hashes %q, %q", a, same)
	}
}
