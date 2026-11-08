package main

import "strings"

// inApp says whether exe is a daemon inside the Mac app: the helper app's
// nushid, somewhere in an `.app`'s Contents.
func inApp(exe string) bool { return strings.Contains(exe, ".app/Contents/") }
