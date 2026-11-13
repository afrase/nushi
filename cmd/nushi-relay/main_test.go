package main

import (
	"net/netip"
	"slices"
	"testing"
)

// -trusted-proxy takes addresses and CIDRs, v4 and v6, each masked, and
// refuses anything else rather than leave it out.
func TestTrustedProxies(t *testing.T) {
	for _, tc := range []struct {
		in   string
		want []string // nil: refused
	}{
		{"", []string{}},
		{"10.0.0.5/8", []string{"10.0.0.0/8"}},
		{"192.0.2.7", []string{"192.0.2.7/32"}},
		{"2001:db8::1", []string{"2001:db8::1/128"}},
		{"2001:db8::1/32", []string{"2001:db8::/32"}},
		{" 127.0.0.1 , ::1 ,", []string{"127.0.0.1/32", "::1/128"}},
		{"proxy.example", nil},
		{"10.0.0.0/33", nil},
		{"10.0.0.1,junk", nil},
	} {
		got, err := trustedProxies(tc.in)
		if tc.want == nil {
			if err == nil {
				t.Errorf("%q: %v, want refused", tc.in, got)
			}
			continue
		}
		if err != nil {
			t.Errorf("%q: %v", tc.in, err)
			continue
		}
		want := make([]netip.Prefix, len(tc.want))
		for i, w := range tc.want {
			want[i] = netip.MustParsePrefix(w)
		}
		if !slices.Equal(got, want) && len(got)+len(want) > 0 {
			t.Errorf("%q: %v, want %v", tc.in, got, want)
		}
	}
}
