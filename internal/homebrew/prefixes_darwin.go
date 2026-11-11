package homebrew

// prefixes are where Homebrew lives on a Mac: /opt/homebrew on Apple
// silicon, /usr/local on Intel (the app's update_toast.dart looks in both
// too).
var prefixes = []string{"/opt/homebrew", "/usr/local"}
