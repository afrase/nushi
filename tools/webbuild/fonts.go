package main

// The engine's fallback fonts: Noto for CJK, emoji, symbols and the other
// scripts, split into woff2 subsets, which the engine fetches from
// fontFallbackBaseUrl only when a character on screen needs one.
// flutter_bootstrap.js points that at assets/fonts/fallback/ on the app's
// own origin (the CSP keeps Google's out), and make web mirrors the files
// there under the paths the engine asks for. The list is the one in
// main.dart.js, which must be fonts.lock's, pinned to the engine's
// revision; each file comes once from Google's font host over https into a
// cache outside the repository and is checked against the lock's sha256.

import (
	"context"
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"
)

//go:embed fonts.lock
var fontsLock string

// notoLicence is the fonts' licence (SIL OFL 1.1), served beside them.
//
//go:embed OFL-Noto.txt
var notoLicence string

const (
	fontHost    = "https://fonts.gstatic.com/s/"
	fallbackDir = "assets/fonts/fallback/"
	lockPath    = "tools/webbuild/fonts.lock"
	maxFont     = 16 << 20
)

// fontRef is a fallback font's path as main.dart.js has it, relative to
// fontFallbackBaseUrl: <family>/v<n>/<name>[.<part>].woff2.
const fontPattern = `[a-z0-9]+/v\d+/[A-Za-z0-9_-]+(?:\.\d+)?\.woff2`

var (
	fontRef     = regexp.MustCompile(`"(` + fontPattern + `)"`)
	fontPathRef = regexp.MustCompile(`^` + fontPattern + `$`)
	engineRef   = regexp.MustCompile(`"engineRevision":"([0-9a-f]{40})"`)
)

// lockedFont is one of fonts.lock's lines.
type lockedFont struct {
	sum  string // sha256, hex
	size int
	path string
}

// onDemand says whether a built file is one of the mirrored fallback fonts
// (or their licence), which the service worker doesn't keep in its shell
// and the relay serves from disk (relay/web.go has the same rule).
func onDemand(name string) bool {
	rest, ok := strings.CutPrefix(name, fallbackDir)
	return ok && (strings.Contains(rest, "/") || rest == "OFL.txt")
}

// engineFonts gives the engine's revision and the fallback fonts its
// script asks for.
func engineFonts(mainJS, boot string) (string, []string) {
	m := engineRef.FindStringSubmatch(boot)
	if m == nil {
		fatalf("webbuild: no engineRevision in flutter_bootstrap.js")
	}
	var paths []string
	for _, f := range fontRef.FindAllStringSubmatch(mainJS, -1) {
		paths = append(paths, f[1])
	}
	slices.Sort(paths)
	paths = slices.Compact(paths)
	if len(paths) < 100 {
		fatalf("webbuild: only %d fallback fonts found in main.dart.js: has the engine's list moved?", len(paths))
	}
	return m[1], paths
}

// parseLock reads fonts.lock: "engine <revision>", then a line per font,
// "<sha256> <size> <path>".
func parseLock(s string) (string, []lockedFont) {
	var engine string
	var fonts []lockedFont
	for line := range strings.Lines(s) {
		f := strings.Fields(line)
		switch {
		case len(f) == 0 || strings.HasPrefix(f[0], "#"):
		case len(f) == 2 && f[0] == "engine":
			engine = f[1]
		case len(f) == 3 && len(f[0]) == 64 && fontPathRef.MatchString(f[2]):
			size, err := strconv.Atoi(f[1])
			check(err)
			fonts = append(fonts, lockedFont{sum: f[0], size: size, path: f[2]})
		default:
			fatalf("webbuild: %s: a bad line %q", lockPath, line)
		}
	}
	return engine, fonts
}

// mirrorFonts puts the engine's fallback fonts under dir's
// assets/fonts/fallback/, with their licence; it returns how many and
// their size.
func mirrorFonts(dir, mainJS, boot string) (int, int) {
	engine, paths := engineFonts(mainJS, boot)
	locked, fonts := parseLock(fontsLock)
	lockedPaths := make([]string, len(fonts))
	for i, f := range fonts {
		lockedPaths[i] = f.path
	}
	if engine != locked || !slices.Equal(paths, lockedPaths) {
		fatalf("webbuild: the engine (%s, %d fallback fonts) isn't the one %s was made for (%s, %d fonts): "+
			"Flutter changed. Run make web-fonts, check the new list and commit it.", engine[:10], len(paths), lockPath, locked[:min(10, len(locked))], len(fonts))
	}
	cache, err := os.UserCacheDir()
	check(err)
	cache = filepath.Join(cache, "nushi", "fallback-fonts")
	total := 0
	forEach(len(fonts), func(i int) error {
		f := fonts[i]
		body, err := cachedFont(cache, f)
		if err != nil {
			return err
		}
		out := filepath.Join(dir, filepath.FromSlash(fallbackDir+f.path))
		if err := os.MkdirAll(filepath.Dir(out), 0o755); err != nil {
			return err
		}
		return os.WriteFile(out, body, 0o644)
	})
	for _, f := range fonts {
		total += f.size
	}
	write(filepath.Join(dir, filepath.FromSlash(fallbackDir+"OFL.txt")), notoLicence)
	return len(fonts), total
}

// cachedFont gives f from the cache, fetching it first if it isn't there;
// either way checked against the lock.
func cachedFont(cache string, f lockedFont) ([]byte, error) {
	name := filepath.Join(cache, filepath.FromSlash(f.path))
	if body, err := os.ReadFile(name); err == nil && sumOf(body) == f.sum {
		return body, nil
	}
	body, err := fetchFont(f.path)
	if err != nil {
		return nil, err
	}
	if sumOf(body) != f.sum || len(body) != f.size {
		return nil, fmt.Errorf("%s%s isn't the font %s locks (sha256 %s, %d bytes): refusing it", fontHost, f.path, lockPath, sumOf(body), len(body))
	}
	if err := os.MkdirAll(filepath.Dir(name), 0o755); err != nil {
		return nil, err
	}
	tmp := name + ".tmp"
	if err := os.WriteFile(tmp, body, 0o644); err != nil {
		return nil, err
	}
	return body, os.Rename(tmp, name)
}

var fontClient = &http.Client{
	Timeout: 2 * time.Minute,
	CheckRedirect: func(*http.Request, []*http.Request) error {
		return errors.New("the font host redirected")
	},
}

// fetchFont gets one font from Google's font host, over https only.
func fetchFont(p string) ([]byte, error) {
	if !fontPathRef.MatchString(p) {
		return nil, fmt.Errorf("not a font's path: %q", p)
	}
	req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, fontHost+p, http.NoBody)
	if err != nil {
		return nil, err
	}
	res, err := fontClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close() //nolint:errcheck // read-only
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%s%s: %s", fontHost, p, res.Status)
	}
	body, err := io.ReadAll(io.LimitReader(res.Body, maxFont+1))
	if err == nil && len(body) > maxFont {
		err = fmt.Errorf("%s%s is over %d MB", fontHost, p, maxFont>>20)
	}
	return body, err
}

// lockFonts writes fonts.lock anew for the app built in dir (make
// web-fonts, after a Flutter upgrade): the engine's revision and each font
// its script asks for, fetched to take its sha256.
func lockFonts(dir string) {
	mainJS := readOne(dir, "main*.dart.js")
	boot := readOne(dir, "flutter_bootstrap*.js")
	engine, paths := engineFonts(mainJS, boot)
	fonts := make([]lockedFont, len(paths))
	for i, p := range paths {
		fonts[i].path = p
	}
	forEach(len(fonts), func(i int) error {
		body, err := fetchFont(fonts[i].path)
		if err != nil {
			return err
		}
		fonts[i].sum, fonts[i].size = sumOf(body), len(body)
		return nil
	})
	var b strings.Builder
	b.WriteString("# The Flutter engine's fallback fonts, which make web mirrors into the web\n" +
		"# app (tools/webbuild/fonts.go): the engine's revision, then each font's\n" +
		"# sha256, size and path under " + fontHost + ".\n" +
		"# Written by make web-fonts; a build with another engine stops.\n")
	b.WriteString("engine " + engine + "\n")
	total := 0
	for _, f := range fonts {
		fmt.Fprintf(&b, "%s %d %s\n", f.sum, f.size, f.path)
		total += f.size
	}
	write(lockPath, b.String())
	log.Printf("%s: engine %s, %d fonts, %d KB", lockPath, engine[:10], len(fonts), total>>10)
}

// forEach runs do for 0..n-1, eight at a time; any error stops the build.
func forEach(n int, do func(int) error) {
	var (
		wg   sync.WaitGroup
		mu   sync.Mutex
		errs []error
		sem  = make(chan struct{}, 8)
	)
	for i := range n {
		wg.Go(func() {
			sem <- struct{}{}
			defer func() { <-sem }()
			if err := do(i); err != nil {
				mu.Lock()
				errs = append(errs, err)
				mu.Unlock()
			}
		})
	}
	wg.Wait()
	check(errors.Join(errs...))
}

func readOne(dir, pattern string) string {
	m, err := filepath.Glob(filepath.Join(dir, pattern))
	check(err)
	m = slices.DeleteFunc(m, func(s string) bool { return path.Ext(s) == ".br" })
	if len(m) != 1 {
		fatalf("webbuild: expected one %s in %s, found %d", pattern, dir, len(m))
	}
	return read(m[0])
}

func sumOf(b []byte) string {
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

// plex is IBM Plex Sans and its italic cut for the web app (make web-plex):
// Latin and the punctuation and symbols the app uses, which the fallback
// fonts complete; source.sha256 names the fonts they were cut from.
//
//go:embed plex
var plex embed.FS

// subsetPlex puts the cut IBM Plex Sans in the place of the whole one,
// if the build's is the one it was cut from.
func subsetPlex(dir string) {
	sums, err := plex.ReadFile("plex/source.sha256")
	check(err)
	for line := range strings.Lines(string(sums)) {
		sum, name, ok := strings.Cut(strings.TrimSpace(line), "  ")
		if !ok {
			fatalf("webbuild: plex/source.sha256: a bad line %q", line)
		}
		out := filepath.Join(dir, "assets", "fonts", name)
		if sumOf([]byte(read(out))) != sum {
			fatalf("webbuild: app/fonts/%s isn't the font tools/webbuild/plex was cut from: run make web-plex and commit it", name)
		}
		cut, err := plex.ReadFile("plex/" + name)
		check(err)
		check(os.WriteFile(out, cut, 0o644))
	}
}

func fatalf(format string, args ...any) {
	log.Fatalf(format, args...) //nolint:revive // the tool's own fatal
}
