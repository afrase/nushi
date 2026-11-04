package ansi

import "testing"

func TestStrip(t *testing.T) {
	for in, want := range map[string]string{
		"\x1b[1;31mred\x1b[0m plain":                                  "red plain",
		"\x1b[?25lspinning\x1b[?25h":                                  "spinning",
		"\x1b[2K\x1b[1Gline":                                          "line",
		"\x1b[38:5:208morange":                                        "orange",
		"\x1b]0;a title\x07after":                                     "after",
		"see \x1b]8;;https://example.com\x1b\\the docs\x1b]8;;\x1b\\": "see the docs",
		"cut \x1b]8;;https://example.com":                             "cut ",
		"no escapes [here]":                                           "no escapes [here]",
	} {
		if got := Strip(in); got != want {
			t.Errorf("Strip(%q) = %q, want %q", in, got, want)
		}
	}
}
