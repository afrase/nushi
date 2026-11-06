package launchfile

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"unicode/utf16"
)

// Source is where an entry was written.
type Source struct {
	Path     string // AgentsFile or ClaudeFile
	FromMain bool   // read from the main checkout (Read's main)
	Index    int    // its place in that file's configurations
}

// Entry is one configured dev server, resolved in the folder as Claude
// resolves it: ${workspaceFolder} and ${workspaceRoot} are the folder,
// and the name and port derived when not given.
type Entry struct {
	// Name is the entry's name, or one derived from its last argument or
	// its url's host when it has none (NameDerived). Repository text: it
	// is shown only marked, and only when ValidName says so is it fit for
	// notes or tool text.
	Name        string
	NameDerived bool
	// Command and Args are what runs: runtimeExecutable, runtimeArgs,
	// program, args; node program args without runtimeExecutable. No
	// command means the entry attaches to a server already running at URL.
	Command string
	Args    []string
	// Cwd is the absolute folder the command runs in, inside the folder
	// (no link leads out of it) when Read ran: CheckCwd checks it again
	// at the start. Empty for an entry with no command.
	Cwd string
	// Port is the port the server is to listen on: the entry's, its
	// localhost url's, the command's (env PORT, --port or -p, a
	// localhost:N or :NNNN in the arguments), else 3000 with a command.
	// Zero only for an entry attaching to an address that isn't local
	// with no port or env PORT.
	Port int
	Env  map[string]string
	// AutoPort is the entry's autoPort: nil when unset.
	AutoPort *bool
	// URL is where the server's page opens instead of
	// http://localhost:<port>, as Claude writes it; empty when not set.
	URL    string
	Source Source
	// Hash is a SHA-256 (hex) of what the entry resolves to, so a server
	// started from it can tell when it changed. Empty with a Problem.
	Hash string
	// Problem says why the entry can't be used, in fixed words naming the
	// key at fault; empty when it can.
	Problem string
}

// name is Claude's rule for a name (its candidates'): what may appear in
// a note or a tool's text.
var name = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9:_.-]{0,63}$`)

// ValidName says whether name is fit to name a server outside its own
// row: a note, a hold, a tool's text. Others are addressed by index.
func ValidName(s string) bool { return name.MatchString(s) }

// place is the folder entries are resolved in: Read's folder, open as a
// root so nothing leads out of it.
type place struct {
	folder string
	root   *os.Root
}

// entry reads one of configurations as Claude parses it
// (docs/facts/claude.md), resolved in p.
func (p place) entry(raw json.RawMessage) Entry {
	c, err := decodeConfig(raw)
	e := Entry{Name: c.name}
	if err != nil {
		e.Problem = err.Error()
		return e
	}
	if err := p.resolve(c, &e); err != nil {
		e.Problem = err.Error()
		return e
	}
	e.Hash = hash(e)
	return e
}

// resolve fills e from c, in Claude's order of checks.
func (p place) resolve(c config, e *Entry) error {
	command, args := c.command()
	if command == "" {
		switch {
		case c.vsCode:
			return errors.New(`VS Code "command" and "node-terminal" entries aren't supported: give "runtimeExecutable", "program", or a "url" alone`)
		case c.url == nil:
			return errors.New(`needs "runtimeExecutable", "program", or a "url" alone`)
		}
	}
	autoPort, err := decodeAutoPort(c.autoPort)
	if err != nil {
		return err
	}
	port, err := decodePort(c.port)
	if err != nil {
		return err
	}
	var to target
	if c.url != nil {
		var s string
		if json.Unmarshal(c.url, &s) != nil || strings.TrimFunc(s, isJSSpace) == "" {
			return errors.New(`"url" must be a non-empty string`)
		}
		if to, err = parseURL(s); err != nil {
			return err
		}
	}
	if command != "" {
		e.Command = p.variables(command)
		e.Args = make([]string, len(args))
		for i, a := range args {
			e.Args[i] = p.variables(a)
		}
		if e.Cwd, err = p.cwd(p.variables(c.cwd)); err != nil {
			return err
		}
	}
	if to.local && port != 0 && to.port != port {
		return errors.New(`"url" is a localhost address on another port than the entry's: it must be the entry's own server`)
	}
	switch {
	case port != 0:
	case to.local && to.port != 0:
		port = to.port
	default:
		port = c.commandPort()
		if port == 0 && command != "" {
			port = 3000
		}
	}
	if port < 0 || port > 65535 {
		return errors.New("the port the command names isn't from 1 to 65535")
	}
	e.Port, e.Env, e.AutoPort, e.URL = port, c.env, autoPort, to.href
	if e.Name == "" {
		e.NameDerived = true
		if command != "" {
			e.Name = derivedName(e.Args)
		} else {
			e.Name = to.host
		}
	}
	return nil
}

// variables is s with ${workspaceFolder} and ${workspaceRoot} the
// folder, the variables Claude puts in a command, its arguments and cwd.
func (p place) variables(s string) string {
	return strings.NewReplacer("${workspaceFolder}", p.folder, "${workspaceRoot}", p.folder).Replace(s)
}

// cwd is where a command runs: cwd (relative to the folder, or absolute)
// when given, else the folder. It must be a folder inside the folder,
// through no link out of it.
func (p place) cwd(cwd string) (string, error) {
	if cwd == "" {
		return p.folder, nil
	}
	return cwdIn(p.root, p.folder, cwd)
}

// CheckCwd checks again that cwd, an Entry's Cwd read from folder (Read's
// folder), is a folder inside folder through no link out of it, as it was
// when read: the starter calls it just before running the command, since
// a folder can have been swapped for a link since (Claude checks at the
// start). A swap between this and the spawn isn't caught.
func CheckCwd(folder, cwd string) error {
	if !filepath.IsAbs(folder) || !filepath.IsAbs(cwd) {
		return errors.New(`"cwd" and its project must be absolute paths`)
	}
	folder = filepath.Clean(folder)
	root, err := os.OpenRoot(folder)
	if err != nil {
		return errors.New(`"cwd": the project's folder can't be opened`)
	}
	defer root.Close() //nolint:errcheck // read-only
	_, err = cwdIn(root, folder, cwd)
	return err
}

// cwdIn is cwd (relative to folder, or absolute) checked through root,
// folder's: a folder inside it through no link out of it.
func cwdIn(root *os.Root, folder, cwd string) (string, error) {
	if !filepath.IsAbs(cwd) {
		cwd = filepath.Join(folder, cwd)
	}
	rel, err := filepath.Rel(folder, filepath.Clean(cwd))
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "", errors.New(`"cwd" must be a folder inside the project's`)
	}
	fi, err := root.Stat(rel)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return "", errors.New(`"cwd" names no folder in the project`)
	case err != nil:
		return "", errors.New(`"cwd" must be a folder inside the project's, through no link out of it`)
	case !fi.IsDir():
		return "", errors.New(`"cwd" must be a folder`)
	}
	return filepath.Join(folder, rel), nil
}

// derivedName is Claude's name for an entry with none and a command: its
// last argument without its extension, ":" made "-", or "preview" when
// that leaves less than two characters (UTF-16 units, as JavaScript
// counts them: one emoji is two).
func derivedName(args []string) string {
	if len(args) == 0 || args[len(args)-1] == "" {
		return "preview"
	}
	last := args[len(args)-1]
	if i := strings.LastIndexByte(last, '.'); i >= 0 && i < len(last)-1 {
		last = last[:i]
	}
	last = strings.ReplaceAll(last, ":", "-")
	if utf16Len(last) < 2 {
		return "preview"
	}
	return last
}

// utf16Len is s's length in UTF-16 units, JavaScript's length.
func utf16Len(s string) int {
	n := 0
	for _, r := range s {
		n += max(utf16.RuneLen(r), 1) // an invalid byte is U+FFFD, one unit
	}
	return n
}

// hash is a SHA-256 of what e resolves to.
func hash(e Entry) string {
	b, _ := json.Marshal(struct { // strings, ints and a bool: it can't fail
		Name, Command string
		Args          []string
		Cwd           string
		Port          int
		Env           map[string]string
		AutoPort      *bool
		URL           string
	}{e.Name, e.Command, e.Args, e.Cwd, e.Port, e.Env, e.AutoPort, e.URL})
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}
