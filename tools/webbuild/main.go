// Command webbuild finishes the phone's web app after flutter build web
// (make web; ADR 0054): it drops what the app doesn't use (the other
// renderers, debug symbols, Flutter's own service worker), gives the
// script, its loader and CanvasKit names with their content's hash (so
// browsers and a CDN keep them for good, and only the page must be asked
// for again), writes the build's files and version into sw.js, and puts a
// Brotli copy beside each file that compresses (name.br; the relay serves
// it to a browser that takes br). It mirrors the engine's fallback fonts
// into the app and puts in IBM Plex Sans cut to what the app needs
// (fonts.go).
//
// With -lock-fonts it writes fonts.lock anew for an app built by flutter
// build web (make web-fonts) and does nothing else.
package main

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/andybalholm/brotli"
)

func main() {
	if len(os.Args) == 3 && os.Args[1] == "-lock-fonts" {
		lockFonts(os.Args[2])
		return
	}
	if len(os.Args) != 2 {
		log.Fatal("usage: webbuild [-lock-fonts] <app/build/web>")
	}
	dir := os.Args[1]
	ck := filepath.Join(dir, "canvaskit")
	entries, err := os.ReadDir(ck)
	check(err)
	for _, e := range entries {
		if e.Name() != "canvaskit.js" && e.Name() != "canvaskit.wasm" {
			check(os.RemoveAll(filepath.Join(ck, e.Name())))
		}
	}
	check(os.RemoveAll(filepath.Join(dir, "flutter_service_worker.js")))
	check(os.RemoveAll(filepath.Join(dir, ".last_build_id")))
	check(os.RemoveAll(filepath.Join(dir, "flutter.js"))) // flutter_bootstrap.js carries it
	dropFont(dir, "Symbols Nerd Font Mono")               // the terminal's, which the phone hasn't
	subsetPlex(dir)

	boot := read(filepath.Join(dir, "flutter_bootstrap.js"))
	fonts, fontsSize := mirrorFonts(dir, read(filepath.Join(dir, "main.dart.js")), boot)
	mainJS := "main." + hashOf(read(filepath.Join(dir, "main.dart.js"))) + ".dart.js"
	check(os.Rename(filepath.Join(dir, "main.dart.js"), filepath.Join(dir, mainJS)))
	boot = replaceOnce(boot, `"mainJsPath":"main.dart.js"`, `"mainJsPath":"`+mainJS+`"`)
	ckDir := "canvaskit-" + hashOf(read(filepath.Join(ck, "canvaskit.js"))+read(filepath.Join(ck, "canvaskit.wasm")))
	check(os.Rename(ck, filepath.Join(dir, ckDir)))
	boot = replaceOnce(boot, `canvasKitBaseUrl: "canvaskit/"`, `canvasKitBaseUrl: "`+ckDir+`/"`)
	check(os.Remove(filepath.Join(dir, "flutter_bootstrap.js")))
	bootJS := "flutter_bootstrap." + hashOf(boot) + ".js"
	write(filepath.Join(dir, bootJS), boot)
	index := filepath.Join(dir, "index.html")
	write(index, replaceOnce(read(index), `src="flutter_bootstrap.js"`, `src="`+bootJS+`"`))

	// The shell the service worker keeps: every file but itself, the
	// licences and the fallback fonts (fetched when a character needs one).
	var shell []string
	all := sha256.New()
	check(fs.WalkDir(os.DirFS(dir), ".", func(name string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || name == "sw.js" || name == "assets/NOTICES" || onDemand(name) {
			return err
		}
		_, _ = fmt.Fprintf(all, "%s\x00%s\x00", name, hashOf(read(filepath.Join(dir, name))))
		if name != "index.html" {
			shell = append(shell, name)
		}
		return nil
	}))
	slices.Sort(shell)
	list, _ := json.Marshal(append([]string{"./"}, shell...))
	sw := read(filepath.Join(dir, "sw.js"))
	sw = replaceOnce(sw, `const VERSION = "nushi-dev";`, `const VERSION = "nushi-`+hex.EncodeToString(all.Sum(nil))[:16]+`";`)
	sw = replaceOnce(sw, `const SHELL = ["./"];`, `const SHELL = `+string(list)+`;`)
	sw = replaceOnce(sw, `const FONTS = "nushi-fonts-dev";`, `const FONTS = "nushi-fonts-`+hashOf(fontsLock)+`";`)
	write(filepath.Join(dir, "sw.js"), sw)
	saved := compress(dir)
	log.Printf("web app: %s, %s, %d files in the shell; Brotli saves %d KB over gzip; %d fallback fonts, %d KB", mainJS, ckDir, len(shell)+1, saved>>10, fonts, fontsSize>>10)
}

// compress writes name.br beside each file of a type that compresses,
// at Brotli's best, when it comes out smaller than gzip would; it returns
// how many bytes that saves over gzip.
func compress(dir string) int {
	saved := 0
	check(fs.WalkDir(os.DirFS(dir), ".", func(name string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !compressible[filepath.Ext(name)] {
			return err
		}
		body := []byte(read(filepath.Join(dir, name)))
		var br, gz bytes.Buffer
		w := brotli.NewWriterLevel(&br, brotli.BestCompression)
		_, _ = w.Write(body)
		check(w.Close())
		z, _ := gzip.NewWriterLevel(&gz, gzip.BestCompression)
		_, _ = z.Write(body)
		check(z.Close())
		if br.Len() < gz.Len() && br.Len() < len(body)*9/10 {
			check(os.WriteFile(filepath.Join(dir, name+".br"), br.Bytes(), 0o644))
			saved += gz.Len() - br.Len()
		}
		return nil
	}))
	return saved
}

// compressible are the types the relay compresses (relay/web.go).
var compressible = map[string]bool{".js": true, ".wasm": true, ".json": true, ".html": true, ".css": true,
	".svg": true, ".otf": true, ".ttf": true, ".frag": true}

// family is a font family in Flutter's FontManifest.json.
type family struct {
	Family string `json:"family"`
	Fonts  []struct {
		Asset string `json:"asset"`
		Style string `json:"style,omitempty"`
	} `json:"fonts"`
}

// dropFont takes name out of the fonts the app loads at start, and its
// files out of the build.
func dropFont(dir, name string) {
	path := filepath.Join(dir, "assets", "FontManifest.json")
	var fonts []family
	check(json.Unmarshal([]byte(read(path)), &fonts))
	i := slices.IndexFunc(fonts, func(f family) bool { return f.Family == name })
	if i < 0 {
		return
	}
	for _, f := range fonts[i].Fonts {
		check(os.Remove(filepath.Join(dir, "assets", filepath.FromSlash(f.Asset))))
	}
	b, _ := json.Marshal(slices.Delete(fonts, i, i+1))
	write(path, string(b))
}

func hashOf(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:8])
}

func replaceOnce(s, old, repl string) string {
	if strings.Count(s, old) != 1 {
		log.Fatalf("webbuild: expected one %q", old) //nolint:revive // the tool's own fatal
	}
	return strings.Replace(s, old, repl, 1)
}

func read(path string) string {
	b, err := os.ReadFile(path)
	check(err)
	return string(b)
}

func write(path, s string) { check(os.WriteFile(path, []byte(s), 0o644)) }

func check(err error) {
	if err != nil {
		log.Fatal(err) //nolint:revive // the tool's own fatal
	}
}
