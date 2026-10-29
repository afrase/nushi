package claudeacp

import "testing"

// A streaming input's complete fields are those a top-level comma has
// closed; commas in strings, objects and arrays don't count.
func TestCompleteFields(t *testing.T) {
	for _, tc := range []struct {
		partial, want string
		n             int
	}{
		{``, ``, 0},
		{`{"a":"x`, ``, 0},
		{`{"a":"x,y"`, ``, 0},
		{`{"a":"x\",y",`, `{"a":"x\",y"}`, 1},
		{`{"a":{"b":1,"c":[1,2]},"d":"`, `{"a":{"b":1,"c":[1,2]}}`, 1},
		{`{"a":1,"b":[1,`, `{"a":1}`, 1},
		{`{"a":1,"b":"\\",`, `{"a":1,"b":"\\"}`, 2},
		{`{"a":1,"b":2}`, `{"a":1}`, 1},
	} {
		got, n := completeFields(tc.partial)
		if string(got) != tc.want || n != tc.n {
			t.Errorf("%s: %s %d, want %s %d", tc.partial, got, n, tc.want, tc.n)
		}
	}
}
