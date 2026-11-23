// Command native-edge checks that the app's native code stays at its edge
// (ADR 0097, 0104, 0125): platform channels and messages (MethodChannel,
// EventChannel, BasicMessageChannel, a BinaryMessenger, a MethodCall or its
// codec, SystemChannels, sendPlatformMessage) and FFI (dart:ffi,
// package:ffi) appear in the Dart libraries it's given only in a platform's
// file, <capability>_macos.dart, <capability>_linux.dart or
// <capability>_windows.dart, its implementation of an interface the
// capability's user declares; a platform's own package only in that
// platform's files (webview_flutter_wkwebview the Mac's, dbus Linux's). No
// file reaches a platform's file (an import, export or part of one) but
// that platform's own, and main.dart, which picks a set
// (native_macos.dart, native_linux.dart or native_windows.dart). It prints
// each use elsewhere and exits 1. make lint-dart runs it from the
// repository root over each Dart package's lib (app/lib when given none).
package main

import (
	"bufio"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/afrase/nushi/tools/dartcheck"
)

// platform is one platform's suffix (a file <capability>_<suffix>.dart is
// its implementation) and what its implementations are called.
type platform struct{ suffix, name string }

var (
	mac     = platform{"macos", "a Mac implementation's file"}
	linux   = platform{"linux", "a Linux implementation's file"}
	windows = platform{"windows", "a Windows implementation's file"}
)

// platforms are every platform with files of its own.
var platforms = []platform{mac, linux, windows}

// native is what only some platforms' files may use, what to call it,
// those platforms, and the one shared file (relative to the root) that
// may use it too, if any.
var native = []struct {
	pattern *regexp.Regexp
	name    string
	in      []platform
	alsoIn  string
}{
	{regexp.MustCompile(`\b(Optional)?MethodChannel\b|\bEventChannel\b|\bBasicMessageChannel\b`), "a platform channel", platforms, ""},
	{regexp.MustCompile(`BinaryMessenger\b|\bMethodCall\b|MethodCodec\b|\bSystemChannels\b|\bsendPlatformMessage\b|\bchannelBuffers\b`), "a platform message", platforms, ""},
	{regexp.MustCompile(`['"]dart:ffi['"]`), "dart:ffi", platforms, ""},
	{regexp.MustCompile(`['"]package:ffi/`), "package:ffi", platforms, ""},
	{regexp.MustCompile(`['"]package:webview_flutter_wkwebview/`), "webview_flutter_wkwebview (macOS's WebKit)", []platform{mac}, ""},
	{regexp.MustCompile(`['"]package:dbus/`), "dbus (Linux's D-Bus)", []platform{linux}, ""},
	// Linux opens links through its runner, never url_launcher, whose launch
	// would pass Nushi's variables on (ADR 0104); web_views.dart uses it
	// only for the phone's web app (kIsWeb).
	{regexp.MustCompile(`['"]package:url_launcher/`), "url_launcher", []platform{mac}, "web_views.dart"},
}

// platformFile is a URI of a platform's file, as an import, export or part
// names it (on its own line too, as a conditional import's), and its suffix.
var platformFile = regexp.MustCompile(`['"]([^'"]*_(macos|linux|windows)\.dart)['"]`)

// picksASet is the one file that may name another platform's file, and
// theSets the ones it may name: main.dart sets the machine's at startup.
const picksASet = "main.dart"

var theSets = []string{"native_macos.dart", "native_linux.dart", "native_windows.dart"}

func main() {
	os.Exit(dartcheck.Run("native-edge", "Native code goes behind an interface its user declares, each platform's implementation in "+
		"<capability>_macos.dart, <capability>_linux.dart or <capability>_windows.dart, reached only through Native "+
		"and chosen in main.dart (native_macos.dart, native_linux.dart or native_windows.dart; ADR 0097, 0104 and 0125, docs/adr/).", check))
}

// check lists the native code in the Dart files under root where it may not
// be, generated code left out.
func check(root string) ([]dartcheck.Use, error) {
	var uses []dartcheck.Use
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		switch {
		case err != nil:
			return err
		case d.IsDir() || !strings.HasSuffix(path, ".dart") || dartcheck.Generated(path):
			return nil
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		own, ok := platformOf(path)
		found, err := inFile(path, filepath.ToSlash(rel), own, ok)
		uses = append(uses, found...)
		return err
	})
	return uses, err
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

// inFile lists the native code in one file (rel, from the root), comments
// left out, that its platform (own, when ok) doesn't allow; the app's
// main.dart may name the sets.
func inFile(path, rel string, own platform, ok bool) ([]dartcheck.Use, error) {
	main := rel == picksASet
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close() //nolint:errcheck // read only
	var uses []dartcheck.Use
	sc := bufio.NewScanner(f)
	for n := 1; sc.Scan(); n++ {
		line := sc.Text()
		if strings.HasPrefix(strings.TrimSpace(line), "//") {
			continue
		}
		for _, k := range native {
			allowed := ok && slices.Contains(k.in, own) || k.alsoIn != "" && rel == k.alsoIn
			if !allowed && k.pattern.MatchString(line) {
				uses = append(uses, dartcheck.Use{Path: path, Line: n, What: k.name + " " + where(k.in)})
			}
		}
		for _, m := range platformFile.FindAllStringSubmatch(line, -1) {
			named, _ := platformOf(m[1])
			switch {
			case main && slices.Contains(theSets, filepath.Base(m[1])):
			case ok && named == own:
			default:
				uses = append(uses, dartcheck.Use{Path: path, Line: n, What: named.name + " (" + m[1] + ")"})
			}
		}
	}
	return uses, sc.Err()
}
