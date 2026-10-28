// Command mermaid puts the pinned mermaid.min.js into the app's assets
// (app/assets/mermaid/, not committed), which the Mac app and the phone's
// web app carry for drawing diagrams; nothing comes from a CDN at runtime.
// make mermaid runs it before each build: the file comes once over https
// from jsDelivr (npm's package as published) into a cache outside the
// repository and is checked against mermaid.lock's sha256 and size.
//
// With -lock <version> it writes mermaid.lock anew for that release,
// taking the file from jsDelivr and unpkg and refusing it unless both
// give the same bytes. Check the diff before committing it.
package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

//go:embed mermaid.lock
var mermaidLock string

const (
	lockPath = "tools/mermaid/mermaid.lock"
	outPath  = "app/assets/mermaid/mermaid.min.js"
	maxSize  = 32 << 20
)

// The places a release's file is fetched from: the first when building,
// both when locking.
var hosts = []string{
	"https://cdn.jsdelivr.net/npm/mermaid@%s/dist/mermaid.min.js",
	"https://unpkg.com/mermaid@%s/dist/mermaid.min.js",
}

var versionRef = regexp.MustCompile(`^\d+\.\d+\.\d+$`)

// pin is what mermaid.lock holds.
type pin struct {
	version string
	sum     string // sha256, hex
	size    int
}

func main() {
	log.SetFlags(0)
	switch {
	case len(os.Args) == 3 && os.Args[1] == "-lock":
		lock(os.Args[2])
	case len(os.Args) == 1:
		install()
	default:
		log.Fatal("usage: mermaid [-lock <version>]")
	}
}

// install puts the locked file at outPath, from the cache or fetched.
func install() {
	p, err := parseLock(mermaidLock)
	check(err)
	if b, err := os.ReadFile(outPath); err == nil && sumOf(b) == p.sum {
		return
	}
	cache, err := os.UserCacheDir()
	check(err)
	cached := filepath.Join(cache, "nushi", "mermaid", p.version, "mermaid.min.js")
	body, err := os.ReadFile(cached)
	if err != nil || sumOf(body) != p.sum {
		body, err = fetch(fmt.Sprintf(hosts[0], p.version))
		check(err)
		if sumOf(body) != p.sum || len(body) != p.size {
			fatalf("mermaid %s isn't the file %s locks (sha256 %s, %d bytes): refusing it", p.version, lockPath, sumOf(body), len(body))
		}
		check(writeAtomic(cached, body))
	}
	check(writeAtomic(outPath, body))
	log.Printf("mermaid %s: %s, %d KB", p.version, outPath, len(body)>>10)
}

// lock writes mermaid.lock for version.
func lock(version string) {
	if !versionRef.MatchString(version) {
		fatalf("not a release's version: %q", version)
	}
	var first []byte
	for _, h := range hosts {
		body, err := fetch(fmt.Sprintf(h, version))
		check(err)
		if first != nil && !bytes.Equal(body, first) {
			fatalf("%s and %s give different files for mermaid %s: refusing both", hosts[0], h, version)
		}
		first = body
	}
	if !bytes.Contains(first[:min(len(first), 64<<10)], []byte("mermaid")) {
		fatalf("that isn't mermaid's script")
	}
	text := "# mermaid.min.js, which make mermaid puts into app/assets/mermaid/ for the\n" +
		"# Mac app and the phone's web app (tools/mermaid): the release, and the\n" +
		"# file's sha256 and size: npm's package's dist/mermaid.min.js, from jsDelivr.\n" +
		"# Written by go run ./tools/mermaid -lock <version>.\n" +
		fmt.Sprintf("version %s\nsha256 %s\nsize %d\n", version, sumOf(first), len(first))
	check(os.WriteFile(lockPath, []byte(text), 0o644))
	log.Printf("%s: mermaid %s, %d KB", lockPath, version, len(first)>>10)
}

// parseLock reads mermaid.lock: "version", "sha256" and "size" lines.
func parseLock(s string) (pin, error) {
	var p pin
	for line := range strings.Lines(s) {
		f := strings.Fields(line)
		switch {
		case len(f) == 0 || strings.HasPrefix(f[0], "#"):
		case len(f) == 2 && f[0] == "version" && versionRef.MatchString(f[1]):
			p.version = f[1]
		case len(f) == 2 && f[0] == "sha256" && len(f[1]) == 64:
			p.sum = f[1]
		case len(f) == 2 && f[0] == "size":
			n, err := strconv.Atoi(f[1])
			if err != nil || n <= 0 || n > maxSize {
				return p, fmt.Errorf("%s: a bad size %q", lockPath, f[1])
			}
			p.size = n
		default:
			return p, fmt.Errorf("%s: a bad line %q", lockPath, line)
		}
	}
	if p.version == "" || p.sum == "" || p.size == 0 {
		return p, fmt.Errorf("%s: a version, a sha256 and a size are needed", lockPath)
	}
	return p, nil
}

var client = &http.Client{
	Timeout: 2 * time.Minute,
	CheckRedirect: func(req *http.Request, _ []*http.Request) error {
		if req.URL.Scheme != "https" {
			return errors.New("redirected off https")
		}
		return nil
	},
}

func fetch(url string) ([]byte, error) {
	req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, url, http.NoBody)
	if err != nil {
		return nil, err
	}
	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close() //nolint:errcheck // read-only
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%s: %s", url, res.Status)
	}
	body, err := io.ReadAll(io.LimitReader(res.Body, maxSize+1))
	if err == nil && len(body) > maxSize {
		err = fmt.Errorf("%s is over %d MB", url, maxSize>>20)
	}
	return body, err
}

func writeAtomic(name string, body []byte) error {
	if err := os.MkdirAll(filepath.Dir(name), 0o755); err != nil {
		return err
	}
	tmp := name + ".tmp"
	if err := os.WriteFile(tmp, body, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, name)
}

func sumOf(b []byte) string {
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

func check(err error) {
	if err != nil {
		log.Fatal(err) //nolint:revive // the tool's own fatal
	}
}

func fatalf(format string, args ...any) {
	log.Fatalf(format, args...) //nolint:revive // the tool's own fatal
}
