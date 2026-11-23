package remote

import "testing"

// The link is the relay's web app with the code in the fragment, as the
// Mac's app built it (app/test/remote_test.dart's vectors).
func TestPairingLink(t *testing.T) {
	for qr, want := range map[string]string{
		"nushi://pair?r=wss%3A%2F%2Frelay.example.com&i=id&k=key&s=secret": "https://relay.example.com/#pair?r=wss%3A%2F%2Frelay.example.com&i=id&k=key&s=secret",
		"nushi://pair?r=ws%3A%2F%2F127.0.0.1%3A8099&i=a":                   "http://127.0.0.1:8099/#pair?r=ws%3A%2F%2F127.0.0.1%3A8099&i=a",
	} {
		if got, err := PairingLink(qr); err != nil || got != want {
			t.Errorf("PairingLink(%q) = %q, %v; want %q", qr, got, err, want)
		}
	}
	for _, qr := range []string{"", "https://relay.example.com/#pair?r=x", "nushi://pair?i=id", "nushi://other?r=wss%3A%2F%2Fr"} {
		if got, err := PairingLink(qr); err == nil {
			t.Errorf("PairingLink(%q) = %q", qr, got)
		}
	}
}
