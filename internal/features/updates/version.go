package updates

import (
	"cmp"
	"slices"
	"strconv"
	"strings"
)

// version is a semantic version: major.minor.patch and its pre-release's
// identifiers ("0.2.0-beta.1"); build metadata ("+12") is left out.
type version struct {
	core [3]int
	pre  []string
}

func parse(s string) (version, bool) {
	s, _, _ = strings.Cut(s, "+")
	s, pre, hasPre := strings.Cut(s, "-")
	parts := strings.Split(s, ".")
	var v version
	if len(parts) != 3 {
		return v, false
	}
	for i, p := range parts {
		n, ok := number(p)
		if !ok {
			return v, false
		}
		v.core[i] = n
	}
	if hasPre {
		v.pre = strings.Split(pre, ".")
		if slices.Contains(v.pre, "") {
			return v, false
		}
	}
	return v, true
}

// number is a numeric identifier's value: digits only.
func number(s string) (int, bool) {
	if s == "" || strings.Trim(s, "0123456789") != "" {
		return 0, false
	}
	n, err := strconv.Atoi(s)
	return n, err == nil
}

// Compare orders two versions as semantic versioning does (a pre-release
// before its release); one that isn't a version is before any that is.
func Compare(a, b string) int {
	va, okA := parse(a)
	vb, okB := parse(b)
	if !okA || !okB {
		return cmp.Compare(boolInt(okA), boolInt(okB))
	}
	for i := range va.core {
		if c := cmp.Compare(va.core[i], vb.core[i]); c != 0 {
			return c
		}
	}
	switch {
	case len(va.pre) == 0 && len(vb.pre) == 0:
		return 0
	case len(va.pre) == 0:
		return 1
	case len(vb.pre) == 0:
		return -1
	}
	for i := 0; i < len(va.pre) && i < len(vb.pre); i++ {
		na, numA := number(va.pre[i])
		nb, numB := number(vb.pre[i])
		var c int
		switch {
		case numA && numB:
			c = cmp.Compare(na, nb)
		case numA != numB: // numeric identifiers come first
			c = cmp.Compare(boolInt(numB), boolInt(numA))
		default:
			c = strings.Compare(va.pre[i], vb.pre[i])
		}
		if c != 0 {
			return c
		}
	}
	return cmp.Compare(len(va.pre), len(vb.pre))
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
