package relayupdate

import (
	"cmp"
	"fmt"
	"strconv"
	"strings"
)

// version is a release's number, X.Y.Z, or a beta's, X.Y.Z-beta.N, which
// comes before X.Y.Z as semver orders them.
type version struct {
	major, minor, patch uint64
	beta                uint64 // 0: not a beta (a beta's N starts at 1)
}

// parseVersion reads this relay's version: X.Y.Z or X.Y.Z-beta.N, as
// tools/release.sh stamps it. Anything else ("dev", a build from the
// repository) has nothing to compare with a release.
func parseVersion(s string) (version, bool) {
	core, beta, isBeta := strings.Cut(s, "-beta.")
	v, ok := parseCore(core)
	if !ok {
		return version{}, false
	}
	if isBeta {
		n, ok := plainNumber(beta)
		if !ok || n == 0 {
			return version{}, false
		}
		v.beta = n
	}
	return v, true
}

// parseTag reads a stable release's tag, vX.Y.Z and nothing else.
func parseTag(tag string) (version, bool) {
	core, ok := strings.CutPrefix(tag, "v")
	if !ok {
		return version{}, false
	}
	return parseCore(core)
}

// parseCore reads X.Y.Z: three plain numbers.
func parseCore(s string) (version, bool) {
	parts := strings.Split(s, ".")
	if len(parts) != 3 {
		return version{}, false
	}
	var n [3]uint64
	for i, p := range parts {
		v, ok := plainNumber(p)
		if !ok {
			return version{}, false
		}
		n[i] = v
	}
	return version{major: n[0], minor: n[1], patch: n[2]}, true
}

// plainNumber reads digits only, without a sign or a leading zero, at most
// nine of them.
func plainNumber(s string) (uint64, bool) {
	if s == "" || len(s) > 9 || (len(s) > 1 && s[0] == '0') {
		return 0, false
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return 0, false
		}
	}
	n, err := strconv.ParseUint(s, 10, 64)
	return n, err == nil
}

// compare orders v and w as semver does: X.Y.Z-beta.N before X.Y.Z.
func (v version) compare(w version) int {
	if c := cmp.Or(cmp.Compare(v.major, w.major), cmp.Compare(v.minor, w.minor), cmp.Compare(v.patch, w.patch)); c != 0 {
		return c
	}
	switch {
	case v.beta == w.beta:
		return 0
	case v.beta == 0:
		return 1
	case w.beta == 0:
		return -1
	}
	return cmp.Compare(v.beta, w.beta)
}

// String is the version as a release names it.
func (v version) String() string {
	s := fmt.Sprintf("%d.%d.%d", v.major, v.minor, v.patch)
	if v.beta != 0 {
		s += fmt.Sprintf("-beta.%d", v.beta)
	}
	return s
}
