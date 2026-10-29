package model

import (
	"strings"
	"testing"
)

func TestSlug(t *testing.T) {
	for in, want := range map[string]string{
		"Add a Mul function":              "add-a-mul-function",
		"":                                "",
		"Café: naïve résumé!!":            "caf-na-ve-r-sum",
		"x" + strings.Repeat(" word", 20): "x-word-word-word-word-word-word-word",
		strings.Repeat("y", 50):           strings.Repeat("y", 40),
	} {
		if got := Slug(in, 40); got != want {
			t.Errorf("%q: %q", in, got)
		}
	}
}
