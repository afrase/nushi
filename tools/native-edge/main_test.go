package main

import (
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestCheck(t *testing.T) {
	root := t.TempDir()
	files := map[string]string{
		"speller.dart":                       "abstract interface class Speller {}\n// a MethodChannel in a comment\n",
		"speller_macos.dart":                 "const _c = MethodChannel('nushi/spelling');\n",
		"view.dart":                          "import 'package:flutter/services.dart';\nconst c = MethodChannel('x');\n",
		"events.dart":                        "final e = EventChannel('y');\n",
		"page.dart":                          "import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';\n",
		"chmod.dart":                         "import 'dart:ffi';\n",
		"phone/scanner_web.dart":             "import 'dart:js_interop';\n",
		"gen/nushi/v1/x.pb.dart":             "const c = MethodChannel('generated');\n",
		"notes.txt":                          "MethodChannel\n",
		"phone/frame_macos.dart":             "import 'dart:ffi';\n",
		"plain.dart":                         "final channel = 'nushi/alerts';\n",
		"basic.dart":                         "BasicMessageChannel<Object?> b;\n",
		"optional.dart":                      "OptionalMethodChannel o;\n",
		"phone/nothing_here.dart":            "void main() {}\n",
		"main.dart":                          "import 'package:nushi/native_macos.dart';\nimport 'package:nushi/alerts_macos.dart';\n",
		"phone_main.dart":                    "import 'package:nushi/native_macos.dart';\n",
		"settings_terminal.dart":             "import 'package:nushi/fonts_macos.dart';\nfinal c = Chan('nushi/fonts');\n",
		"cond.dart":                          "export 'package:nushi/x_web.dart'\n    if (dart.library.ffi) 'package:nushi/x_macos.dart';\n",
		"parts.dart":                         "part 'parts_macos.dart';\n",
		"ffi_cond.dart":                      "import 'package:nushi/x.dart' if (dart.library.ffi) 'dart:ffi' as ffi;\n",
		"messenger.dart":                     "final f = ServicesBinding.instance.defaultBinaryMessenger.send('nushi/fonts', const StandardMethodCodec().encodeMethodCall(const MethodCall('monospaced')));\n",
		"system.dart":                        "SystemChannels.platform.invokeMethod<void>('x');\n",
		"dispatch.dart":                      "ui.PlatformDispatcher.instance.sendPlatformMessage('x', null, null);\n",
		"logs.dart":                          "PlatformDispatcher.instance.onError = (e, s) => true;\n",
		"gen/sneaky.dart":                    "const c = MethodChannel('nushi/sneaky');\n",
		"gen/nushi/v1/x.connect.client.dart": "const c = MethodChannel('generated');\n",
	}
	for name, body := range files {
		path := filepath.Join(root, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	uses, err := check(root)
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, u := range uses {
		rel, _ := filepath.Rel(root, u.path)
		got = append(got, rel+": "+u.what)
	}
	slices.Sort(got)
	want := []string{
		"basic.dart: a platform channel",
		"chmod.dart: dart:ffi",
		"cond.dart: a Mac implementation's file (package:nushi/x_macos.dart)",
		"dispatch.dart: a platform message",
		"events.dart: a platform channel",
		"ffi_cond.dart: dart:ffi",
		"gen/sneaky.dart: a platform channel",
		"main.dart: a Mac implementation's file (package:nushi/alerts_macos.dart)",
		"messenger.dart: a platform message",
		"optional.dart: a platform channel",
		"page.dart: webview_flutter_wkwebview (macOS's WebKit)",
		"parts.dart: a Mac implementation's file (parts_macos.dart)",
		"phone_main.dart: a Mac implementation's file (package:nushi/native_macos.dart)",
		"settings_terminal.dart: a Mac implementation's file (package:nushi/fonts_macos.dart)",
		"system.dart: a platform message",
		"view.dart: a platform channel",
	}
	if !slices.Equal(got, want) {
		t.Errorf("got %q\nwant %q", got, want)
	}
}

// The app and its Dart packages as they are keep their native code at the
// edge.
func TestTheApp(t *testing.T) {
	roots, err := filepath.Glob(filepath.Join("..", "..", "packages", "*", "lib"))
	if err != nil {
		t.Fatal(err)
	}
	for _, root := range append(roots, filepath.Join("..", "..", "app", "lib")) {
		uses, err := check(root)
		if err != nil {
			t.Fatal(err)
		}
		for _, u := range uses {
			t.Errorf("%s:%d: %s", u.path, u.line, u.what)
		}
	}
}
