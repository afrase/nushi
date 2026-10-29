package secrets

import (
	"regexp"
	"testing"
)

func TestMask(t *testing.T) {
	name := regexp.MustCompile(`((?i)\b[A-Za-z_]\w*token=)\S{4,}`)
	for _, tc := range []struct{ in, want string }{
		{"key sk-ant-api03-abcdefghijklmnopqrstuv end", "key ** end"},
		{"fw_3ZabcdefghijklmnopqrstUV", "**"},
		{"ghp_abcdefghijklmnopqrstuvwxyz0123456789 github_pat_11ABCDEFG0123456789_abcdefghij", "** **"},
		{"xoxb-123456789012-abcdefghijkl xoxp-123456789012-abcdefghijkl", "** **"},
		{"AIzaSyA-abcdefghijklmnopqrstuvwxyz01234", "**"},
		{"AKIAIOSFODNN7EXAMPLE", "**"},
		{"jwt eyJhbGciOiJI.eyJzdWIiOiIx.SflKxwRJSMeKKF2QT4f", "jwt **"},
		{"Authorization: Bearer abc.def-ghi_jkl", "Authorization: Bearer **"},
		{"basic dXNlcjpwYXNzd29yZA==", "basic **"},
		{"https://me:hunter22@example.com/x", "https://me:**@example.com/x"},
		{"a\n-----BEGIN RSA PRIVATE KEY-----\nMIIEow\n-----END RSA PRIVATE KEY-----\nb", "a\n-----BEGIN RSA PRIVATE KEY-----**\nb"},
		{"-----BEGIN OPENSSH PRIVATE KEY-----\nb3Blbn", "-----BEGIN OPENSSH PRIVATE KEY-----**"}, // cut before its end
		{"GH_TOKEN=abcd1234 next", "GH_TOKEN=** next"},                                           // extra's rule
		{"GH_TOKEN=ghp_abcdefghijklmnopqrstuvwxyz0123456789", "GH_TOKEN=**"},                     // both
		{"session 019a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8 ok", "session 019a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8 ok"},
		{"sk-short", "sk-short"},
		{"", ""},
	} {
		if got := Mask(tc.in, "**", name); got != tc.want {
			t.Errorf("Mask(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
	if got := Mask("GH_TOKEN=abcd1234", "**", nil); got != "GH_TOKEN=abcd1234" {
		t.Errorf("without extra: %q", got)
	}
}
