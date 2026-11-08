// Package procfs reads Linux's /proc without cgo: each process's stat
// (parent, group, session, terminal, start time), its command line and
// its open files, for proctree, listeners, footprint and claudehistory's
// Linux files (ADR 0097). Only the user's own processes matter: an entry
// that can't be read, or has gone, is skipped, never an error for a whole
// list.
//
// The readers are in procfs_linux.go; the parsers of what they read are
// in parse.go, which builds everywhere so their tests run on the Mac too.
package procfs
