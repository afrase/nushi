package main

import (
	"os"
	"path/filepath"
	"slices"
	"testing"
)

// What each kind of use is called, outside the files that may hold it.
const (
	channel   = "a platform channel outside a *_macos.dart or *_linux.dart file"
	message   = "a platform message outside a *_macos.dart or *_linux.dart file"
	ffi       = "dart:ffi outside a *_macos.dart or *_linux.dart file"
	webKit    = "webview_flutter_wkwebview (macOS's WebKit) outside a *_macos.dart file"
	dbus      = "dbus (Linux's D-Bus) outside a *_linux.dart file"
	macFile   = "a Mac implementation's file "
	linuxFile = "a Linux implementation's file "
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
		"main.dart":                          "import 'package:nushi/native_macos.dart';\nimport 'package:nushi/alerts_macos.dart';\nimport 'package:nushi/native_linux.dart';\nimport 'package:nushi/alerts_linux.dart';\n",
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
		// A platform's own files: its channels, FFI and packages, and its
		// own files named, never another platform's.
		"speller_linux.dart":    "import 'dart:ffi';\nimport 'package:dbus/dbus.dart';\nconst c = MethodChannel('nushi/x');\n",
		"native_linux.dart":     "import 'package:nushi/speller_linux.dart';\n",
		"web_views_macos.dart":  "import 'package:nushi/web_page_macos.dart';\nimport 'package:webview_flutter_wkwebview/x.dart';\n",
		"alerts_macos.dart":     "import 'package:dbus/dbus.dart';\nimport 'package:nushi/alerts_linux.dart';\n",
		"web_views_linux.dart":  "import 'package:webview_flutter_wkwebview/x.dart';\nimport 'package:nushi/web_page_macos.dart';\n",
		"notify.dart":           "import 'package:dbus/dbus.dart';\n",
		"status.dart":           "import 'package:nushi/alerts_linux.dart';\n",
		"phone/scan_linux.dart": "import 'package:nushi/native_linux.dart';\n",
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
		"alerts_macos.dart: " + linuxFile + "(package:nushi/alerts_linux.dart)",
		"alerts_macos.dart: " + dbus,
		"basic.dart: " + channel,
		"chmod.dart: " + ffi,
		"cond.dart: " + macFile + "(package:nushi/x_macos.dart)",
		"dispatch.dart: " + message,
		"events.dart: " + channel,
		"ffi_cond.dart: " + ffi,
		"gen/sneaky.dart: " + channel,
		"main.dart: " + linuxFile + "(package:nushi/alerts_linux.dart)",
		"main.dart: " + macFile + "(package:nushi/alerts_macos.dart)",
		"messenger.dart: " + message,
		"notify.dart: " + dbus,
		"optional.dart: " + channel,
		"page.dart: " + webKit,
		"parts.dart: " + macFile + "(parts_macos.dart)",
		"phone_main.dart: " + macFile + "(package:nushi/native_macos.dart)",
		"settings_terminal.dart: " + macFile + "(package:nushi/fonts_macos.dart)",
		"status.dart: " + linuxFile + "(package:nushi/alerts_linux.dart)",
		"system.dart: " + message,
		"view.dart: " + channel,
		"web_views_linux.dart: " + macFile + "(package:nushi/web_page_macos.dart)",
		"web_views_linux.dart: " + webKit,
	}
	if !slices.Equal(got, want) {
		t.Errorf("got %q\nwant %q", got, want)
	}
}
