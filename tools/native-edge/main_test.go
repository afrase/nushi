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
		"speller.dart":            "abstract interface class Speller {}\n// a MethodChannel in a comment\n",
		"speller_macos.dart":      "const _c = MethodChannel('nushi/spelling');\n",
		"view.dart":               "import 'package:flutter/services.dart';\nconst c = MethodChannel('x');\n",
		"events.dart":             "final e = EventChannel('y');\n",
		"page.dart":               "import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';\n",
		"chmod.dart":              "import 'dart:ffi';\n",
		"phone/scanner_web.dart":  "import 'dart:js_interop';\n",
		"gen/nushi/v1/x.pb.dart":  "const c = MethodChannel('generated');\n",
		"notes.txt":               "MethodChannel\n",
		"phone/frame_macos.dart":  "import 'dart:ffi';\n",
		"plain.dart":              "final channel = 'nushi/alerts';\n",
		"basic.dart":              "BasicMessageChannel<Object?> b;\n",
		"optional.dart":           "OptionalMethodChannel o;\n",
		"phone/nothing_here.dart": "void main() {}\n",
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
		"events.dart: a platform channel",
		"optional.dart: a platform channel",
		"page.dart: webview_flutter_wkwebview (macOS's WebKit)",
		"view.dart: a platform channel",
	}
	if !slices.Equal(got, want) {
		t.Errorf("got %q\nwant %q", got, want)
	}
}

// The app as it is keeps its native code at its edge.
func TestTheApp(t *testing.T) {
	uses, err := check(filepath.Join("..", "..", "app", "lib"))
	if err != nil {
		t.Fatal(err)
	}
	for _, u := range uses {
		t.Errorf("%s:%d: %s", u.path, u.line, u.what)
	}
}
