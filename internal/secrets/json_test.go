package secrets

import "testing"

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
		{``, ``},
	} {
		if got := MaskJSONIn(tc.in, "**"); got != tc.want {
			t.Errorf("MaskJSONIn(%q)\n = %q\nwant %q", tc.in, got, tc.want)
		}
	}
}
