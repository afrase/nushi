package relayupdate

import "testing"

// Versions order as semver: numbers compared as numbers, a beta before
// its release.
func TestVersionOrder(t *testing.T) {
	ordered := []string{"0.9.9", "0.10.0", "1.2.9", "1.3.0-beta.1", "1.3.0-beta.2", "1.3.0-beta.10", "1.3.0", "1.3.1", "10.0.0"}
	for i, a := range ordered {
		va, ok := parseVersion(a)
		if !ok {
			t.Fatalf("%s refused", a)
		}
		if va.String() != a {
			t.Errorf("%s reads back as %s", a, va)
		}
		for j, b := range ordered {
			vb, _ := parseVersion(b)
			if got, want := va.compare(vb), cmpInt(i, j); got != want {
				t.Errorf("%s vs %s: %d, want %d", a, b, got, want)
			}
		}
	}
	for _, bad := range []string{"dev", "", "1.2", "1.2.3.4", "v1.2.3", "01.2.3", "1.2.3-beta", "1.2.3-beta.0", "1.2.3-beta.01", "1.2.3-rc.1", "1.2.-3", "1.2.+3", "1.2.3 ", "1234567890.0.0"} {
		if _, ok := parseVersion(bad); ok {
			t.Errorf("%q accepted", bad)
		}
	}
	if v, ok := parseTag("v1.3.0"); !ok || v.String() != "1.3.0" {
		t.Errorf("v1.3.0: %v %v", v, ok)
	}
	for _, bad := range []string{"1.3.0", "v1.3.0-beta.1", "V1.3.0", "vv1.3.0"} {
		if _, ok := parseTag(bad); ok {
			t.Errorf("tag %q accepted", bad)
		}
	}
}

func cmpInt(a, b int) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	}
	return 0
}

// A unit's name is letters, digits and :_.@- only, and no option.
func TestCheckUnit(t *testing.T) {
	for _, ok := range []string{"nushi-relay", "nushi-relay.service", "relay@main:1_a.service"} {
		if err := CheckUnit(ok); err != nil {
			t.Errorf("%q: %v", ok, err)
		}
	}
	for _, bad := range []string{"", "-h", "--now", "a b", "a;b", "a/b", "a\nb", "é", string(make([]byte, 300))} {
		if err := CheckUnit(bad); err == nil {
			t.Errorf("%q accepted", bad)
		}
	}
}
