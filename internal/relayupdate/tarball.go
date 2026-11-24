package relayupdate

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"strings"

	"github.com/afrase/nushi/internal/atomicfile"
)

// binaryName is the one file a release's relay tarball holds.
const binaryName = "nushi-relay"

// checkSum compares the tarball's SHA-256 with the first field of its
// .sha256 (`shasum -a 256`'s line: the sum, two spaces, the file's name).
// The sum is public, so a plain comparison would do; this one is constant
// time anyway.
func checkSum(tarball, sumFile []byte, name string) error {
	fields := strings.Fields(string(sumFile))
	if len(fields) == 0 || len(fields[0]) != sha256.Size*2 {
		return fmt.Errorf("%s.sha256 doesn't start with a SHA-256", name)
	}
	want, err := hex.DecodeString(fields[0])
	if err != nil {
		return fmt.Errorf("%s.sha256 doesn't start with a SHA-256: %w", name, err)
	}
	got := sha256.Sum256(tarball)
	if subtle.ConstantTimeCompare(got[:], want) != 1 {
		return fmt.Errorf("%s doesn't match its .sha256 (it is %x)", name, got)
	}
	return nil
}

// stageBinary writes the tarball's one file beside target, not yet in its
// place: the tarball must hold exactly one entry, a regular file named
// nushi-relay of at most limit bytes, or nothing is left behind.
func stageBinary(tarball []byte, target string, limit int64) (*atomicfile.Staged, error) {
	zr, err := gzip.NewReader(bytes.NewReader(tarball))
	if err != nil {
		return nil, fmt.Errorf("reading the tarball: %w", err)
	}
	tr := tar.NewReader(zr)
	hdr, err := tr.Next()
	if errors.Is(err, io.EOF) {
		return nil, errors.New("the tarball is empty")
	}
	if err != nil {
		return nil, fmt.Errorf("reading the tarball: %w", err)
	}
	switch {
	case hdr.Name != binaryName:
		return nil, fmt.Errorf("the tarball holds %q, not %s", hdr.Name, binaryName)
	case hdr.Typeflag != tar.TypeReg:
		return nil, fmt.Errorf("the tarball's %s isn't a regular file", binaryName)
	case hdr.Size > limit:
		return nil, fmt.Errorf("the tarball's %s is %d bytes, more than %d", binaryName, hdr.Size, limit)
	}
	s, err := atomicfile.Stage(target, tr, 0o700) // the old file's mode is set once it's checked
	if err != nil {
		return nil, fmt.Errorf("writing beside %s: %w", target, err)
	}
	if hdr, err := tr.Next(); !errors.Is(err, io.EOF) {
		s.Discard()
		if err != nil {
			return nil, fmt.Errorf("reading the tarball: %w", err)
		}
		return nil, fmt.Errorf("the tarball holds %q too, not only %s", hdr.Name, binaryName)
	}
	return s, nil
}
