package npm

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha512"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"testing/fstest"
)

// tarball packs files as npm packs a package (under package/).
func tarball(t *testing.T, files map[string]string) []byte {
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	for name, body := range files {
		tw.WriteHeader(&tar.Header{Name: "package/" + name, Mode: 0o644, Size: int64(len(body)), Typeflag: tar.TypeReg})
		tw.Write([]byte(body))
	}
	tw.Close()
	gz.Close()
	return buf.Bytes()
}

// A registry of four packages on localhost, and a lockfile for them as
// the npm registry would resolve them: a, its dependency b, its optional
// dependency c, and s, whose install script would leave a file in marker's
// folder. Changing a's tarball after the lockfile was written breaks its
// hash.
func registry(t *testing.T, marker string) (url string, lock fstest.MapFS, tamper func()) {
	pkgs := map[string][]byte{
		"a": tarball(t, map[string]string{"package.json": `{"name":"a","version":"1.0.0","bin":{"a":"bin/a.js"},"dependencies":{"b":"2.0.0","s":"1.0.0"},"optionalDependencies":{"c":"1.0.0"}}`, "bin/a.js": "#!/usr/bin/env node\n"}),
		"b": tarball(t, map[string]string{"package.json": `{"name":"b","version":"2.0.0"}`}),
		"c": tarball(t, map[string]string{"package.json": `{"name":"c","version":"1.0.0"}`}),
		"s": tarball(t, map[string]string{"package.json": `{"name":"s","version":"1.0.0","scripts":{"postinstall":"touch ` + marker + `"}}`}),
	}
	served := map[string][]byte{}
	packages := map[string]any{"": map[string]any{"dependencies": map[string]string{"a": "1.0.0"}}}
	for name, tgz := range pkgs {
		version := map[string]string{"b": "2.0.0"}[name]
		if version == "" {
			version = "1.0.0"
		}
		path := "/" + name + "/-/" + name + "-" + version + ".tgz"
		served[path] = tgz
		sum := sha512.Sum512(tgz)
		entry := map[string]any{"version": version, "resolved": "https://registry.npmjs.org" + path, "integrity": "sha512-" + base64.StdEncoding.EncodeToString(sum[:])}
		switch name {
		case "a":
			entry["bin"] = map[string]string{"a": "bin/a.js"}
			entry["dependencies"] = map[string]string{"b": "2.0.0", "s": "1.0.0"}
			entry["optionalDependencies"] = map[string]string{"c": "1.0.0"}
		case "c":
			entry["optional"] = true
		case "s":
			entry["hasInstallScript"] = true
		}
		packages["node_modules/"+name] = entry
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if b, ok := served[r.URL.Path]; ok {
			w.Write(b)
			return
		}
		http.NotFound(w, r)
	}))
	t.Cleanup(srv.Close)
	lockJSON, _ := json.Marshal(map[string]any{"name": "x", "lockfileVersion": 3, "requires": true, "packages": packages})
	lock = fstest.MapFS{
		"package.json":      {Data: []byte(`{"private":true,"dependencies":{"a":"1.0.0"}}`)},
		"package-lock.json": {Data: lockJSON},
	}
	return srv.URL, lock, func() {
		served["/a/-/a-1.0.0.tgz"] = tarball(t, map[string]string{"package.json": `{"name":"a","version":"1.0.0"}`})
	}
}

// npm ci from the lockfile, against the local registry, with its own
// settings and HOME: the packages are installed, the optional one and the
// install script left out, npm's cache gone; a changed tarball fails and
// leaves the install before it; Remove.
func TestInstall(t *testing.T) {
	if _, err := exec.LookPath("npm"); err != nil {
		t.Skip("no npm")
	}
	tmp := t.TempDir()
	marker := filepath.Join(tmp, "script-ran")
	url, lock, tamper := registry(t, marker)
	npmrc := filepath.Join(tmp, "npmrc")
	os.WriteFile(npmrc, []byte("registry="+url+"/\nfetch-retries=0\n"), 0o600) // no retries of the changed tarball
	t.Setenv("HOME", filepath.Join(tmp, "home"))
	in := Installer{Env: []string{"npm_config_userconfig=" + npmrc, "npm_config_globalconfig=" + npmrc + ".global"}}
	folder := filepath.Join(tmp, "agents", "x")
	readied := 0
	for range 2 { // the second replaces the first
		if err := in.Install(context.Background(), lock, folder, func() { readied++ }); err != nil {
			t.Fatal(err)
		}
	}
	version, program := in.Installed(folder, "a", "a")
	if version != "1.0.0" || program != filepath.Join(folder, "node_modules/a/bin/a.js") || readied != 2 {
		t.Errorf("%q %q, ready %d times", version, program, readied)
	}
	if v, _ := in.Installed(folder, "b", "b"); v != "" {
		t.Errorf("b has no program, yet %q", v)
	}
	for _, gone := range []string{"node_modules/c", ".npm", "../home"} {
		if _, err := os.Stat(filepath.Join(folder, gone)); err == nil {
			t.Errorf("%s is there", gone)
		}
	}
	if _, err := os.Stat(marker); err == nil {
		t.Error("an install script ran")
	}
	if left, _ := filepath.Glob(filepath.Join(tmp, "agents", ".*")); len(left) > 0 {
		t.Errorf("left behind: %s", left)
	}

	tamper()
	if err := in.Install(context.Background(), lock, folder, func() { t.Error("ready after a failed install") }); err == nil {
		t.Error("a tarball that isn't the lockfile's installed")
	}
	if v, _ := in.Installed(folder, "a", "a"); v != "1.0.0" {
		t.Error("a failed install took the one before")
	}
	if err := in.Remove(folder); err != nil {
		t.Fatal(err)
	}
	if v, _ := in.Installed(folder, "a", "a"); v != "" {
		t.Error("still installed after Remove")
	}
}
