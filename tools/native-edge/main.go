// Command native-edge checks that the app's native code stays at its edge
// (ADR 0097): platform channels (MethodChannel, EventChannel,
// BasicMessageChannel), FFI (dart:ffi) and a macOS-only package
// (webview_flutter_wkwebview) appear in app/lib only in a file named
// <capability>_macos.dart, the Mac's implementation of an interface its
// user declares. It prints each use elsewhere and exits 1. make lint-dart
// runs it from the repository root.
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
	{regexp.MustCompile(`^\s*(import|export)\s+['"]dart:ffi['"]`), "dart:ffi"},
	{regexp.MustCompile(`['"]package:ffi/`), "package:ffi"},
	{regexp.MustCompile(`['"]package:webview_flutter_wkwebview/`), "webview_flutter_wkwebview (macOS's WebKit)"},
}

// use is one line of a file that uses native code.
type use struct {
	path string
	line int
	what string
}

func main() {
	root := "app/lib"
	if len(os.Args) > 1 {
		root = os.Args[1]
	}
	uses, err := check(root)
	if err != nil {
		fmt.Fprintln(os.Stderr, "native-edge:", err)
		os.Exit(2)
	}
	for _, u := range uses {
		fmt.Fprintf(os.Stderr, "%s:%d: %s outside a *_macos.dart file\n", u.path, u.line, u.what)
	}
	if len(uses) > 0 {
		fmt.Fprintln(os.Stderr, "Native code goes behind an interface its user declares, the Mac's implementation in "+
			"<capability>_macos.dart, chosen in native_macos.dart (ADR 0097, docs/adr/0097-native-code-behind-interfaces.md).")
		os.Exit(1)
	}
}

// check lists the native code in the Dart files under root, the generated
// code (lib/gen) and the Mac's own files left out.
func check(root string) ([]use, error) {
	var uses []use
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		switch {
		case err != nil:
			return err
		case d.IsDir() && path == filepath.Join(root, "gen"):
			return filepath.SkipDir
		case d.IsDir() || !strings.HasSuffix(path, ".dart") || strings.HasSuffix(path, "_macos.dart"):
			return nil
		}
		found, err := inFile(path)
		uses = append(uses, found...)
		return err
	})
	return uses, err
}

// inFile lists the native code in one file, comments left out.
func inFile(path string) ([]use, error) {
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
	}
	return uses, sc.Err()
}
