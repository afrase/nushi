// Command native-edge checks that the app's native code stays at its edge
// (ADR 0097): platform channels and messages (MethodChannel, EventChannel,
// BasicMessageChannel, a BinaryMessenger, a MethodCall or its codec,
// SystemChannels, sendPlatformMessage), FFI (dart:ffi, package:ffi) and a
// macOS-only package (webview_flutter_wkwebview) appear in the Dart
// libraries it's given only in a file named <capability>_macos.dart, the
// Mac's implementation of an interface its user declares; and no other
// file reaches one of those (an import, export or part of a *_macos.dart
// file), but main.dart, which picks the Mac's set (native_macos.dart). It
// prints each use elsewhere and exits 1. make lint-dart runs it from the
// repository root over each Dart package's lib (app/lib when given none).
package main

import (
	"bufio"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// native is what only a *_macos.dart file may use, and what to call it.
var native = []struct {
	pattern *regexp.Regexp
	name    string
}{
	{regexp.MustCompile(`\b(Optional)?MethodChannel\b|\bEventChannel\b|\bBasicMessageChannel\b`), "a platform channel"},
	{regexp.MustCompile(`BinaryMessenger\b|\bMethodCall\b|MethodCodec\b|\bSystemChannels\b|\bsendPlatformMessage\b|\bchannelBuffers\b`), "a platform message"},
	{regexp.MustCompile(`['"]dart:ffi['"]`), "dart:ffi"},
	{regexp.MustCompile(`['"]package:ffi/`), "package:ffi"},
	{regexp.MustCompile(`['"]package:webview_flutter_wkwebview/`), "webview_flutter_wkwebview (macOS's WebKit)"},
}

// macosFile is a URI of a Mac implementation's file, as an import, export
// or part names it (on its own line too, as a conditional import's).
var macosFile = regexp.MustCompile(`['"]([^'"]*_macos\.dart)['"]`)

// picksTheMac is the one file that may name a *_macos.dart file, and the
// one it may name: main.dart sets the Mac's set at startup.
const picksTheMac, theMacsSet = "main.dart", "native_macos.dart"

// generated are the suffixes of protoc's and Connect's Dart, left out.
var generated = []string{".pb.dart", ".pbenum.dart", ".pbjson.dart", ".pbserver.dart", ".pbgrpc.dart"}

// use is one line of a file that uses native code.
type use struct {
	path string
	line int
	what string
}

func main() {
	roots := os.Args[1:]
	if len(roots) == 0 {
		roots = []string{"app/lib"}
	}
	var uses []use
	for _, root := range roots {
		found, err := check(root)
		if err != nil {
			fmt.Fprintln(os.Stderr, "native-edge:", err)
			os.Exit(2)
		}
		uses = append(uses, found...)
	}
	for _, u := range uses {
		fmt.Fprintf(os.Stderr, "%s:%d: %s outside a *_macos.dart file\n", u.path, u.line, u.what)
	}
	if len(uses) > 0 {
		fmt.Fprintln(os.Stderr, "Native code goes behind an interface its user declares, the Mac's implementation in "+
			"<capability>_macos.dart, reached only through Native and chosen in main.dart's native_macos.dart "+
			"(ADR 0097, docs/adr/0097-native-code-behind-interfaces.md).")
		os.Exit(1)
	}
}

// check lists the native code in the Dart files under root, generated code
// and the Mac's own files left out.
func check(root string) ([]use, error) {
	var uses []use
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		switch {
		case err != nil:
			return err
		case d.IsDir() || !strings.HasSuffix(path, ".dart") || strings.HasSuffix(path, "_macos.dart") || isGenerated(path):
			return nil
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		found, err := inFile(path, rel == picksTheMac)
		uses = append(uses, found...)
		return err
	})
	return uses, err
}

// isGenerated says whether path is protoc's or Connect's output.
func isGenerated(path string) bool {
	base := filepath.Base(path)
	for _, s := range generated {
		if strings.HasSuffix(base, s) {
			return true
		}
	}
	return strings.Contains(base, ".connect.")
}

// inFile lists the native code in one file, comments left out; main is
// whether it's the app's main.dart, which may name the Mac's set.
func inFile(path string, main bool) ([]use, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close() //nolint:errcheck // read only
	var uses []use
	sc := bufio.NewScanner(f)
	for n := 1; sc.Scan(); n++ {
		line := sc.Text()
		if strings.HasPrefix(strings.TrimSpace(line), "//") {
			continue
		}
		for _, k := range native {
			if k.pattern.MatchString(line) {
				uses = append(uses, use{path, n, k.name})
			}
		}
		for _, m := range macosFile.FindAllStringSubmatch(line, -1) {
			if !main || filepath.Base(m[1]) != theMacsSet {
				uses = append(uses, use{path, n, "a Mac implementation's file (" + m[1] + ")"})
			}
		}
	}
	return uses, sc.Err()
}
