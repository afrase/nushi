package main

import (
	"slices"
	"strconv"
	"strings"
	"testing"
)

// The lock is whole: an engine, and each font once, in order, with a sum
// and a size.
func TestFontsLock(t *testing.T) {
	engine, fonts := parseLock(fontsLock)
	if len(engine) != 40 || len(fonts) < 100 {
		t.Fatalf("engine %q, %d fonts", engine, len(fonts))
	}
	paths := make([]string, len(fonts))
	for i, f := range fonts {
		paths[i] = f.path
		if f.size <= 0 || f.size > maxFont || len(f.sum) != 64 {
			t.Errorf("%s: %d bytes, sum %q", f.path, f.size, f.sum)
		}
	}
	if !slices.IsSorted(paths) || len(slices.Compact(slices.Clone(paths))) != len(paths) {
		t.Error("the paths aren't sorted and unique")
	}
	for _, family := range []string{"notosansjp/", "notocoloremoji/", "notosanssymbols2/", "notosans/"} {
		if !slices.ContainsFunc(paths, func(p string) bool { return strings.HasPrefix(p, family) }) {
			t.Errorf("no %s", family)
		}
	}
}

// The fonts the engine finds in a script, and the files kept out of the
// service worker's shell (relay/web.go's onDisk has the same rule).
func TestEngineFontsAndOnDemand(t *testing.T) {
	var b strings.Builder
	b.WriteString(`a="notosansjp/v53/x-Y_z.0.woff2";b=c+"roboto/v32/KFOm.woff2";d="notosansjp/v53/x-Y_z.0.woff2";e="../v1/x.woff2"`)
	for i := range 120 {
		b.WriteString(`,"notocoloremoji/v32/e.` + strconv.Itoa(i) + `.woff2"`)
	}
	js := b.String()
	engine, paths := engineFonts(js, `{"engineRevision":"`+strings.Repeat("ab", 20)+`"}`)
	if engine != strings.Repeat("ab", 20) || !slices.Contains(paths, "notosansjp/v53/x-Y_z.0.woff2") || !slices.Contains(paths, "roboto/v32/KFOm.woff2") ||
		slices.ContainsFunc(paths, func(p string) bool { return strings.Contains(p, "..") }) {
		t.Errorf("engine %q, paths %v", engine, paths[:3])
	}
	for name, want := range map[string]bool{
		"assets/fonts/fallback/notosansjp/v53/x.0.woff2": true,
		"assets/fonts/fallback/OFL.txt":                  true,
		"assets/fonts/fallback/Roboto-Regular.ttf":       false,
		"assets/fonts/IBMPlexSans.ttf":                   false,
		"main.0123.dart.js":                              false,
	} {
		if onDemand(name) != want {
			t.Errorf("onDemand(%q) = %v", name, !want)
		}
	}
}
