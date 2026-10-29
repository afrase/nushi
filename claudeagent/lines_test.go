package claudeagent

import (
	"errors"
	"io"
	"strings"
	"testing"
)

func TestLineReader(t *testing.T) {
	type line struct {
		text string
		over int
	}
	long := strings.Repeat("x", 100<<10) // longer than the reader's buffer
	for _, tc := range []struct {
		name string
		in   string
		max  int
		want []line
	}{
		{"lines", "a\nbc\n\nd", 10, []line{{"a", 0}, {"bc", 0}, {"", 0}, {"d", 0}}},
		{"at the cap", "12345\n", 5, []line{{"12345", 0}}},
		{"over the cap, then on", "123456\nok\n", 5, []line{{"", 6}, {"ok", 0}}},
		{"last line over the cap", "123456", 5, []line{{"", 6}}},
		{"longer than the buffer", long + "\n" + long + "y\nz\n", len(long), []line{{long, 0}, {"", len(long) + 1}, {"z", 0}}},
		{"empty", "", 5, nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			lr := newLineReader(strings.NewReader(tc.in), tc.max)
			var got []line
			for {
				l, over, err := lr.next()
				if errors.Is(err, io.EOF) {
					break
				}
				if err != nil {
					t.Fatal(err)
				}
				got = append(got, line{string(l), over})
			}
			if len(got) != len(tc.want) {
				t.Fatalf("%d lines, want %d", len(got), len(tc.want))
			}
			for i := range got {
				if got[i] != tc.want[i] {
					t.Errorf("line %d: %.20q (%d over), want %.20q (%d over)", i, got[i].text, got[i].over, tc.want[i].text, tc.want[i].over)
				}
			}
		})
	}
}
