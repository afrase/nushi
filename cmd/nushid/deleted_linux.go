package main

import (
	"os"
	"path/filepath"
)

// inApp says whether exe is a daemon inside the Linux app's package (ADR
// 0104): `lib/nushid`, with the app's binary, `nushi`, in the folder above.
// Removing the package removes both; an upgrade puts them back within
// seconds.
func inApp(exe string) bool {
	lib := filepath.Dir(exe)
	if filepath.Base(exe) != "nushid" || filepath.Base(lib) != "lib" {
		return false
	}
	st, err := os.Stat(filepath.Join(filepath.Dir(lib), "nushi"))
	return err == nil && st.Mode().IsRegular()
}
