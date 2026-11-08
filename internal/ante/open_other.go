//go:build !darwin && !linux

package ante

// openFiles has no way to see another process's open files here: none is
// open, so a session is never said to be held.
func openFiles([]string, func(string) string) map[string]string { return map[string]string{} }
