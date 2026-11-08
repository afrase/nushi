package main

import "testing"

// The daemon runs with no arguments or -login; anything else is refused,
// so `nushid -h` starts no daemon.
func TestDaemonArgs(t *testing.T) {
	for _, tc := range []struct {
		args  []string
		login bool
		ok    bool
	}{
		{nil, false, true},
		{[]string{"-login"}, true, true},
		{[]string{"-psn_0_12345", "-login"}, true, true},
		{[]string{"-h"}, false, false},
		{[]string{"--help"}, false, false},
		{[]string{"-login", "extra"}, false, false},
		{[]string{"login"}, false, false},
	} {
		login, err := daemonArgs(tc.args)
		if login != tc.login || (err == nil) != tc.ok {
			t.Errorf("daemonArgs(%q) = %v, %v", tc.args, login, err)
		}
	}
}
