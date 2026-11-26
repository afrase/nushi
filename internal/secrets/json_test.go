package secrets

import (
	"strings"
	"testing"
)

// A JSON object anywhere in a text (a line of a program's output, or a
// fragment of one) has its secret-named values masked where they stand,
// every other byte kept; what isn't JSON is left alone.
func TestMaskJSONIn(t *testing.T) {
	for _, tc := range []struct{ in, want string }{
		{`{"error":"unauthorized","token":"FAKEjson0003"}`, `{"error":"unauthorized","token":"**"}`},
		{`{"access_token": "FAKEjson0004", "expires_in": 3600}`, `{"access_token": "**", "expires_in": 3600}`},
		{`HTTP 401: {"error": {"message": "bad", "api_key": "FAKE"}} at x`, `HTTP 401: {"error": {"message": "bad", "api_key": "**"}} at x`},
		{"body {\n  \"password\": 123456,\n  \"user\": \"me\"\n}\nnext", "body {\n  \"password\": \"**\",\n  \"user\": \"me\"\n}\nnext"},
		{`{"credentials": {"id": "a", "secret": ["s1", 2]}}`, `{"credentials": {"id": "**", "secret": ["**", "**"]}}`},
		{`{"max_tokens": 100, "token": ""}`, `{"max_tokens": 100, "token": ""}`},          // a count, and nothing to hide
		{`{"tokenizer": "cl100k"}`, `{"tokenizer": "cl100k"}`},                            // a tokenizer's name
		{`{"tok\u0065n": "x\"y"} {"token": "y"}`, `{"tok\u0065n": "**"} {"token": "**"}`}, // a key as JSON spells it
		{`{oops {"token": "z"}`, `{oops {"token": "**"}`},                                 // the first brace isn't JSON, the second is
		{`{"token": "cut off`, `{"token": "cut off`},                                      // not JSON: the name rules' to catch
		{`no json { here }`, `no json { here }`},
		// JSON pasted unescaped inside a JSON string: the brace in the
		// failed try's string is tried too (the verifier's three).
		{`{"x": "a {"password": ["FAKEarr", 7]}`, `{"x": "a {"password": ["**", "**"]}`},
		{`{"error": "invalid", "detail": "body was {"password": "fake horse battery staple"}"}`, `{"error": "invalid", "detail": "body was {"password": "**"}"}`},
		{`{"a": "unterminated {"token": "abc"}`, `{"a": "unterminated {"token": "**"}`},
		{``, ``},
	} {
		if got := MaskJSONIn(tc.in, "**"); got != tc.want {
			t.Errorf("MaskJSONIn(%q)\n = %q\nwant %q", tc.in, got, tc.want)
		}
	}
}

// The whole text is scanned, however long: an object past 256 KiB (where
// the scan once stopped) and one after another 4 MiB, as much as PiG's
// check keeps of a server's output.
func TestMaskJSONInLongText(t *testing.T) {
	for _, pad := range []int{300 << 10, 4 << 20} {
		s := strings.Repeat("x ", pad/2) + `{"token": "FAKElong"}`
		if got := MaskJSONIn(s, "**"); strings.Contains(got, "FAKElong") {
			t.Errorf("%d bytes in: the token shows", pad)
		}
	}
}

// An object that is cut off keeps the whole objects inside it: each is
// masked on its own, as a fragment would be.
func TestMaskJSONInCutOff(t *testing.T) {
	for _, tc := range []struct{ in, want string }{
		{`{"a": {"token": "x"}, "b": [{"password": 1}]`, `{"a": {"token": "**"}, "b": [{"password": "**"}]`},
		{`{"secret": {"id": "a"}, "x":`, `{"secret": {"id": "a"}, "x":`}, // on its own, id names no secret
		{`{"a": {"b": {"token": "x"}} oops {"api_key": "y"}`, `{"a": {"b": {"token": "**"}} oops {"api_key": "**"}`},
		{`{{"token": "x"}}`, `{{"token": "**"}}`},
	} {
		if got := MaskJSONIn(tc.in, "**"); got != tc.want {
			t.Errorf("MaskJSONIn(%q)\n = %q\nwant %q", tc.in, got, tc.want)
		}
	}
	deep := strings.Repeat(`{"a":`, 3*maxJSONDepth) + `{"token":"x"}` + strings.Repeat("}", 3*maxJSONDepth)
	if got, want := MaskJSONIn(deep, "**"), strings.Replace(deep, `"x"`, `"**"`, 1); got != want {
		t.Errorf("past the depth cap, the token isn't masked alone: …%s…", got[len(got)/2-30:len(got)/2+30])
	}
}

// hostile are texts a server's author could print to make the scan
// slow: braces that never close, nesting past any real JSON's, and a
// long object followed by what isn't one.
func hostile(size int) map[string]string {
	deep := size / (len(`{"a":`) + 1)
	long := `{"token":"x","b":[` + strings.Repeat("1,", size/4) + `1]}`
	return map[string]string{
		"braces":             strings.Repeat("{", size),
		"open keys":          strings.Repeat(`{"a":`, size/5),
		"arrays of braces":   strings.Repeat("[{", size/2),
		"deep valid":         strings.Repeat(`{"a":`, deep) + "1" + strings.Repeat("}", deep),
		"long then junk":     long + strings.Repeat(`{"a":`, (size-len(long))/5),
		"braces in a key":    `{"` + strings.Repeat("{", size),
		"cut-off nesting":    strings.Repeat(`{"a":[{"b":{}},`, size/16),
		"braces in strings":  strings.Repeat(`{"a":"{"`, size/8),
		"pasted chain":       strings.Repeat(`{"a": "x {"b": "y `, size/18),
		"long string braces": `{"a":"` + strings.Repeat("{", size) + `" x`,
	}
}

// The scan reads each byte a bounded number of times, whatever the text:
// counted, not timed. Three times for the scan, and twice more at most
// for the braces inside failed tries' strings.
func TestMaskJSONInIsLinear(t *testing.T) {
	for name, s := range hostile(200 << 10) {
		_, read := maskJSONIn(s, "**")
		if read > 5*len(s) {
			t.Errorf("%s: read %d bytes of %d (%.1f times)", name, read, len(s), float64(read)/float64(len(s)))
		}
	}
}

func BenchmarkMaskJSONIn(b *testing.B) {
	in := hostile(200 << 10)
	for _, name := range []string{"braces", "open keys", "deep valid", "long then junk", "cut-off nesting"} {
		b.Run(name, func(b *testing.B) {
			for b.Loop() {
				MaskJSONIn(in[name], "**")
			}
		})
	}
}
