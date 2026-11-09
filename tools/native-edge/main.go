// Command native-edge checks that the app's native code stays at its edge
// (ADR 0097, 0104): platform channels and messages (MethodChannel,
// EventChannel, BasicMessageChannel, a BinaryMessenger, a MethodCall or its
// codec, SystemChannels, sendPlatformMessage) and FFI (dart:ffi,
// package:ffi) appear in the Dart libraries it's given only in a platform's
// file, <capability>_macos.dart or <capability>_linux.dart, its
// implementation of an interface the capability's user declares; a
// platform's own package only in that platform's files
// (webview_flutter_wkwebview the Mac's, dbus Linux's). No file reaches a
// platform's file (an import, export or part of one) but that platform's
// own, and main.dart, which picks a set (native_macos.dart or
// native_linux.dart). It prints each use elsewhere and exits 1. make
// lint-dart runs it from the repository root over each Dart package's lib
// (app/lib when given none).
package main

import (
	"bufio"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

// platform is one platform's suffix (a file <capability>_<suffix>.dart is
// its implementation) and what its implementations are called.
type platform struct{ suffix, name string }

var (
	mac   = platform{"macos", "a Mac implementation's file"}
	linux = platform{"linux", "a Linux implementation's file"}
)

// platforms are every platform with files of its own.
var platforms = []platform{mac, linux}

// native is what only some platforms' files may use, what to call it, and
// those platforms.
var native = []struct {
	pattern *regexp.Regexp
	name    string
	in      []platform
}{
	{regexp.MustCompile(`\b(Optional)?MethodChannel\b|\bEventChannel\b|\bBasicMessageChannel\b`), "a platform channel", platforms},
	{regexp.MustCompile(`BinaryMessenger\b|\bMethodCall\b|MethodCodec\b|\bSystemChannels\b|\bsendPlatformMessage\b|\bchannelBuffers\b`), "a platform message", platforms},
	{regexp.MustCompile(`['"]dart:ffi['"]`), "dart:ffi", platforms},
	{regexp.MustCompile(`['"]package:ffi/`), "package:ffi", platforms},
	{regexp.MustCompile(`['"]package:webview_flutter_wkwebview/`), "webview_flutter_wkwebview (macOS's WebKit)", []platform{mac}},
	{regexp.MustCompile(`['"]package:dbus/`), "dbus (Linux's D-Bus)", []platform{linux}},
}

// platformFile is a URI of a platform's file, as an import, export or part
// names it (on its own line too, as a conditional import's), and its suffix.
var platformFile = regexp.MustCompile(`['"]([^'"]*_(macos|linux)\.dart)['"]`)

// picksASet is the one file that may name another platform's file, and
// theSets the ones it may name: main.dart sets the machine's at startup.
const picksASet = "main.dart"

var theSets = []string{"native_macos.dart", "native_linux.dart"}

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
		fmt.Fprintf(os.Stderr, "%s:%d: %s\n", u.path, u.line, u.what)
	}
	if len(uses) > 0 {
		fmt.Fprintln(os.Stderr, "Native code goes behind an interface its user declares, each platform's implementation in "+
			"<capability>_macos.dart or <capability>_linux.dart, reached only through Native and chosen in main.dart "+
			"(native_macos.dart or native_linux.dart; ADR 0097 and 0104, docs/adr/).")
		os.Exit(1)
	}
}

// check lists the native code in the Dart files under root where it may not
// be, generated code left out.
func check(root string) ([]use, error) {
	var uses []use
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		switch {
		case err != nil:
			return err
		case d.IsDir() || !strings.HasSuffix(path, ".dart") || isGenerated(path):
			return nil
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		own, ok := platformOf(path)
		found, err := inFile(path, own, ok, rel == picksASet)
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

// platformOf is the platform whose file path is, if any.
func platformOf(path string) (platform, bool) {
	for _, p := range platforms {
		if strings.HasSuffix(path, "_"+p.suffix+".dart") {
			return p, true
		}
	}
	return platform{}, false
}

// where says which files may hold what only the platforms in may use.
func where(in []platform) string {
	files := make([]string, len(in))
	for i, p := range in {
		files[i] = "*_" + p.suffix + ".dart"
	}
	return "outside a " + strings.Join(files, " or ") + " file"
}

// inFile lists the native code in one file, comments left out, that its
// platform (own, when ok) doesn't allow; main is whether it's the app's
// main.dart, which may name the sets.
func inFile(path string, own platform, ok, main bool) ([]use, error) {
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
			allowed := ok && slices.Contains(k.in, own)
			if !allowed && k.pattern.MatchString(line) {
				uses = append(uses, use{path, n, k.name + " " + where(k.in)})
			}
		}
		for _, m := range platformFile.FindAllStringSubmatch(line, -1) {
			named, _ := platformOf(m[1])
			switch {
			case main && slices.Contains(theSets, filepath.Base(m[1])):
			case ok && named == own:
			default:
				uses = append(uses, use{path, n, named.name + " (" + m[1] + ")"})
			}
		}
	}
	return uses, sc.Err()
}
