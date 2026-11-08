package skillfile

// TrashProgram moves a file, its last argument, to the Trash: gio's
// (glib's, on most desktops), found on PATH, which keeps the freedesktop
// Trash spec (a .Trash-$uid folder on another filesystem) and trashes a
// link, not what it points at; tests swap in their own.
var TrashProgram = []string{"gio", "trash", "--"}
