// Package projecticon finds a project's own icon in its folder: a small
// PNG or JPEG at one of a short list of likely paths, for the project's
// tile in the app's sidebar (ADR 0112). The files are a repository's,
// which anyone may have written: only a regular file inside the folder is
// read, at most so much of it, and only one whose header says it's a
// small, about square image.
package projecticon

import (
	"bytes"
	"errors"
	"io/fs"
	"os"
	"strings"
	"syscall"

	"github.com/afrase/nushi/internal/imagesize"
	"github.com/afrase/nushi/internal/regularfile"
)

const (
	// MaxBytes is the largest file taken as an icon.
	MaxBytes = 256 << 10
	// MaxSide and minSide are the most and the fewest pixels along an
	// icon's side: a tile is 38 points square, and a favicon of 16 is a
	// blur there.
	MaxSide = 1024
	minSide = 32
	// mostEntries is how many names of an icon set's folder are read.
	mostEntries = 64
)

// ownMarks are a repository's own mark, looked at first; appIcons and
// siteIcons an app's icon and a site's, after the icon sets. Each is a
// path without its ending, tried as .png then .jpg, in order.
var (
	ownMarks = []string{
		"icon",
		"logo",
		".github/icon",
		".github/logo",
		"assets/icon",
		"assets/logo",
		"docs/images/logo",
	}
	appIcons = []string{
		"build/icon",
		"src-tauri/icons/icon",
	}
	siteIcons = []string{
		"public/icon",
		"public/logo",
		"public/favicon",
		"static/favicon",
		"web/favicon",
		"app/web/favicon",
	}
)

// iconSets are the macOS icon sets looked at, between ownMarks and
// appIcons: of each, the PNG with the most pixels that fits.
var iconSets = []string{
	"Assets.xcassets/AppIcon.appiconset",
	"macos/Runner/Assets.xcassets/AppIcon.appiconset",
	"app/macos/Runner/Assets.xcassets/AppIcon.appiconset",
}

// Icon is an image's bytes and their type: "image/png" or "image/jpeg",
// from what the bytes are, not the file's name.
type Icon struct {
	MimeType string
	Data     []byte
}

// Find is the icon of the project in folder, and whether it has one. A
// path that's missing, isn't a regular file, leads out of folder, is too
// large or isn't such an image is passed over for the next.
func Find(folder string) (Icon, bool) {
	root, err := os.OpenRoot(folder)
	if err != nil {
		return Icon{}, false
	}
	defer root.Close() //nolint:errcheck // read-only
	if icon, ok := named(root, ownMarks); ok {
		return icon, true
	}
	for _, set := range iconSets {
		if icon, ok := largest(root, set); ok {
			return icon, true
		}
	}
	if icon, ok := named(root, appIcons); ok {
		return icon, true
	}
	return named(root, siteIcons)
}

// named is the first of stems, as .png then .jpg, that's an icon.
func named(root *os.Root, stems []string) (Icon, bool) {
	for _, stem := range stems {
		for _, ext := range []string{".png", ".jpg"} {
			if icon, _, err := read(root, stem+ext); err == nil {
				return icon, true
			}
		}
	}
	return Icon{}, false
}

// largest is the icon with the most pixels among the PNGs of the icon
// set at dir. Only a folder is opened, never a link, a fifo or a device:
// the Lstat says it's one before the open, and the open itself takes
// only a folder and never waits, so a fifo put there since can't hang it.
func largest(root *os.Root, dir string) (Icon, bool) {
	if fi, err := root.Lstat(dir); err != nil || !fi.IsDir() {
		return Icon{}, false
	}
	d, err := root.OpenFile(dir, os.O_RDONLY|syscall.O_DIRECTORY|syscall.O_NONBLOCK, 0)
	if err != nil {
		return Icon{}, false
	}
	entries, _ := d.ReadDir(mostEntries)
	_ = d.Close()
	var best Icon
	most := 0
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".png") {
			continue
		}
		if icon, side, err := read(root, dir+"/"+e.Name()); err == nil && side > most {
			best, most = icon, side
		}
	}
	return best, most > 0
}

var errNotIcon = errors.New("not a small square PNG or JPEG")

// read is the icon at name inside root, and its longer side in pixels.
// A link isn't followed, wherever it leads.
func read(root *os.Root, name string) (Icon, int, error) {
	f, fi, err := regularfile.OpenIn(root, name, false)
	if err != nil {
		return Icon{}, 0, err
	}
	defer f.Close() //nolint:errcheck // read-only
	data, err := regularfile.ReadAll(f, fi, MaxBytes)
	if err != nil {
		return Icon{}, 0, err
	}
	mime := kind(data)
	w, h := imagesize.OfBytes(data)
	long, short := max(w, h), min(w, h)
	// About square: a wide wordmark is unreadable in a tile.
	if mime == "" || short < minSide || long > MaxSide || 2*long > 3*short {
		return Icon{}, 0, &fs.PathError{Op: "read", Path: name, Err: errNotIcon}
	}
	return Icon{MimeType: mime, Data: data}, long, nil
}

// kind is the type data's first bytes say, "" for neither.
func kind(data []byte) string {
	switch {
	case bytes.HasPrefix(data, []byte("\x89PNG\r\n\x1a\n")):
		return "image/png"
	case bytes.HasPrefix(data, []byte{0xFF, 0xD8, 0xFF}):
		return "image/jpeg"
	}
	return ""
}
