//go:build !unix

package relayupdate

import "os"

// copyOwner does nothing where files have no Unix owner: a release has no
// relay there, and Run refuses before it gets here.
func copyOwner(string, os.FileInfo) error { return nil }
