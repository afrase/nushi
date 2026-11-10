package opencodeskills

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

func read(t *testing.T, file string) string {
	t.Helper()
	b, err := os.ReadFile(file)
	testcheck.NoErr(t, err)
	return string(b)
}

// set turns the skill mine off or on from the deeper folder and says how
// it is listed after.
func set(t *testing.T, deeper string, on bool) string {
	t.Helper()
	ctx := context.Background()
	testcheck.NoErr(t, OpenCode{}.SetSkillOn(ctx, deeper, "user", "mine", on))
	l, _ := OpenCode{}.List(ctx, deeper)
	s, _ := l.Find("user", "mine")
	return s.State + " " + s.SetIn
}

// Without a config file, off makes opencode.json, yours alone.
func TestSwitchMakesTheFile(t *testing.T) {
	config, _, deeper := setup(t)
	file := filepath.Join(config, "opencode.json")
	if g := set(t, deeper, false); g != "off " {
		t.Errorf("after off: %q", g)
	}
	if g, want := read(t, file), "{\n  \"policies\": [\n    "+deny("mine")+"\n  ]\n}\n"; g != want {
		t.Errorf("made:\n%s", g)
	}
	if fi, _ := os.Stat(file); fi.Mode().Perm() != 0o600 {
		t.Errorf("mode %v", fi.Mode())
	}
	if g := set(t, deeper, true); g != "on " || read(t, file) != "{\n}\n" {
		t.Errorf("after on: %q, %q", g, read(t, file))
	}
	testcheck.NoErr(t, OpenCode{}.SetSkillOn(context.Background(), deeper, "user", "mine", true)) // as it is already
	if _, err := os.Stat(filepath.Join(config, "opencode.jsonc")); err == nil || read(t, file) != "{\n}\n" {
		t.Error("turning on what is on wrote something")
	}
}

// Off adds one entry to the file's text and on takes it out: every other
// byte, and the file's mode, stay.
func TestSwitchKeepsTheFile(t *testing.T) {
	config, _, deeper := setup(t)
	file := filepath.Join(config, "opencode.json")
	const before = `{
  "$schema": "https://opencode.ai/config.json",
  "zeta": {"b": 1,   "a": [1,2]},
  "policies": [
    {"effect": "deny", "action": "tool.use", "resource": "bash"},
    {"action":"skill.use","resource":"other","effect":"deny"}
  ],
  "model": "local/fake"
}
`
	testcheck.Write(t, file, before)
	testcheck.NoErr(t, os.Chmod(file, 0o644))
	if g := set(t, deeper, false); g != "off " {
		t.Errorf("after off: %q", g)
	}
	want := strings.Replace(before, `"effect":"deny"}`+"\n", `"effect":"deny"},`+"\n    "+deny("mine")+"\n", 1)
	if g := read(t, file); g != want {
		t.Errorf("after off:\n%s\nwant\n%s", g, want)
	}
	if g := set(t, deeper, true); g != "on " || read(t, file) != before {
		t.Errorf("after on: %q\n%s", g, read(t, file))
	}
	if fi, _ := os.Stat(file); fi.Mode().Perm() != 0o644 {
		t.Errorf("mode %v", fi.Mode())
	}
}

// A commented opencode.jsonc on its own is changed in place, comments
// and trailing commas kept, and no opencode.json is made beside it.
func TestSwitchJSONC(t *testing.T) {
	config, _, deeper := setup(t)
	file := filepath.Join(config, "opencode.jsonc")
	const before = `// My opencode settings.
{
	/* which model */ "model": "local/fake", // the fake
	"policies": [
		// no shell
		{"action": "tool.use", "resource": "bash", "effect": "deny"}, // ever
	],
} // } the end
`
	testcheck.Write(t, file, before)
	if g := set(t, deeper, false); g != "off " {
		t.Errorf("after off: %q", g)
	}
	want := strings.Replace(before, "// ever\n", "// ever\n\t\t"+deny("mine")+",\n", 1)
	if g := read(t, file); g != want {
		t.Errorf("after off:\n%s\nwant\n%s", g, want)
	}
	if g := set(t, deeper, true); g != "on " || read(t, file) != before {
		t.Errorf("after on: %q\n%s", g, read(t, file))
	}
	if _, err := os.Stat(filepath.Join(config, "opencode.json")); err == nil {
		t.Error("an opencode.json was made")
	}
}

// With both files, off goes to opencode.json, which opencode reads
// first; on takes Nushi's entries out of both.
func TestSwitchBothFiles(t *testing.T) {
	config, _, deeper := setup(t)
	json, jsonc := filepath.Join(config, "opencode.json"), filepath.Join(config, "opencode.jsonc")
	testcheck.Write(t, json, `{"model": "local/fake"}`)
	testcheck.Write(t, jsonc, "{\n  // mine\n  \"policies\": [\n    "+deny("mine")+", "+deny("older")+"\n  ]\n}\n")
	if g := set(t, deeper, true); g != "on " || read(t, json) != `{"model": "local/fake"}` {
		t.Errorf("after on: %q, %s", g, read(t, json))
	}
	if g, want := read(t, jsonc), "{\n  // mine\n  \"policies\": [\n    "+deny("older")+"\n  ]\n}\n"; g != want {
		t.Errorf("opencode.jsonc after on:\n%s", g)
	}
	if g := set(t, deeper, false); g != "off " || read(t, json) != `{"model": "local/fake", "policies": [`+deny("mine")+`]}` {
		t.Errorf("after off: %q, %s", g, read(t, json))
	}
	if !strings.Contains(read(t, jsonc), "// mine") || strings.Contains(read(t, jsonc), `"mine"`) {
		t.Errorf("opencode.jsonc after off:\n%s", read(t, jsonc))
	}
}

// A file that doesn't read is never written: the list says why nothing
// switches, and the switch names the file.
func TestSwitchMalformed(t *testing.T) {
	ctx := context.Background()
	for name, text := range map[string]string{"opencode.json": `{"policies": [`, "opencode.jsonc": `["policies"]`} {
		config, _, deeper := setup(t)
		file := filepath.Join(config, name)
		testcheck.Write(t, file, text)
		l, err := OpenCode{}.List(ctx, deeper)
		if err != nil || !strings.Contains(l.NoSwitch, file+" doesn't read") || len(l.Skills) == 0 {
			t.Errorf("%s: no switch %q, %d skills, %v", name, l.NoSwitch, len(l.Skills), err)
		}
		for _, on := range []bool{false, true} {
			if err := (OpenCode{}).SetSkillOn(ctx, deeper, "user", "mine", on); err == nil || !strings.Contains(err.Error(), file) {
				t.Errorf("%s, on %v: %v", name, on, err)
			}
		}
		if g := read(t, file); g != text {
			t.Errorf("%s was written: %s", name, g)
		}
		if _, err := os.Stat(filepath.Join(config, "opencode.json")); name != "opencode.json" && err == nil {
			t.Error("an opencode.json was made beside it")
		}
	}
}

// What Nushi can't switch by an entry of its own, it leaves alone and
// says so.
func TestSwitchRefused(t *testing.T) {
	config, _, deeper := setup(t)
	skill(t, filepath.Join(config, "skills"), "we?rd")
	skill(t, filepath.Join(config, "skills"), "{env:HOME}")
	file := filepath.Join(config, "opencode.json")
	text := `{"policies": [` + deny("claude*") + `, {"action": "skill.use", "resource": "older", "effect": "deny" /* mine */}], "policies": []}`
	testcheck.Write(t, file, text)
	ctx := context.Background()
	for _, c := range []struct {
		source, name string
		on           bool
		want         string
	}{
		{"user", "nope", false, `no user skill "nope"`},
		{"project", "mine", false, `no project skill "mine"`},
		{"user", "we?rd", false, "can't name the skill"},
		{"user", "{env:HOME}", false, "can't name the skill"},
		{"user", "mine", false, `it has "policies" twice): add ` + deny("mine")},
	} {
		if err := (OpenCode{}).SetSkillOn(ctx, deeper, c.source, c.name, c.on); err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s %s: %v", c.source, c.name, err)
		}
	}
	if read(t, file) != text {
		t.Errorf("written: %s", read(t, file))
	}
	text = `{"policies": [` + deny("claude*") + `, {"action": "skill.use", "resource": "older", "effect": "deny" /* mine */}, ` + deny("mine") + `, ` + deny("mine") + `]}`
	testcheck.Write(t, file, text)
	for _, name := range []string{"claudeuser", "older"} { // a pattern's, and an entry with a comment in it
		if err := (OpenCode{}).SetSkillOn(ctx, deeper, "user", name, true); err == nil || !strings.Contains(err.Error(), "it's off in "+file+"; change it there") {
			t.Errorf("%s: %v", name, err)
		}
	}
	if g := set(t, deeper, true); g != "on " || read(t, file) != strings.Replace(text, `, `+deny("mine")+`, `+deny("mine"), "", 1) {
		t.Errorf("two entries of Nushi's: %q, %s", g, read(t, file))
	}
}

// The entry goes in as the file is laid out, and comes out leaving the
// text as it was.
func TestEdited(t *testing.T) {
	it := deny("it")
	for _, c := range []struct{ before, after string }{
		{"{}", `{"policies": [` + it + `]}`},
		{"{\n}\n", "{\n  \"policies\": [\n    " + it + "\n  ]\n}\n"},
		{`{"a": 1}`, `{"a": 1, "policies": [` + it + `]}`},
		{`{"a": 1,}`, `{"a": 1, "policies": [` + it + `],}`},
		{"{\n  \"a\": 1 // one\n}\n", "{\n  \"a\": 1, // one\n  \"policies\": [\n    " + it + "\n  ]\n}\n"},
		{"{\n\t\"a\": 1,\n}\n", "{\n\t\"a\": 1,\n\t\"policies\": [\n\t\t" + it + "\n\t],\n}\n"},
		{"{\r\n  \"a\": 1\r\n}\r\n", "{\r\n  \"a\": 1,\r\n  \"policies\": [\r\n    " + it + "\r\n  ]\r\n}\r\n"},
		{"{\"policies\": [\n  // none yet\n]}", "{\"policies\": [\n  // none yet\n  " + it + "\n]}"},
		{`{"policies": [{"x": 1}]}`, `{"policies": [{"x": 1}, ` + it + `]}`},
		{`{"policies": [{"x": 1},]}`, `{"policies": [{"x": 1}, ` + it + `,]}`},
		{`{"policies": [{"x": 1} /* } */], "b": "]"} // }`, `{"policies": [{"x": 1}, ` + it + ` /* } */], "b": "]"} // }`},
		{"{\"policies\": [\n  {\"x\": 1}, {\"y\": 2}\n]}", "{\"policies\": [\n  {\"x\": 1}, {\"y\": 2},\n  " + it + "\n]}"},
	} {
		out, err := edited([]byte(c.before), "it", true)
		if err != nil || string(out) != c.after || !only([]byte(c.before), out, "it", true) {
			t.Errorf("adding to %q: %q, %v", c.before, out, err)
			continue
		}
		back, err := edited(out, "it", false)
		if err != nil || string(back) != c.before || !only(out, back, "it", false) {
			t.Errorf("taking out of %q: %q, %v", out, back, err)
		}
	}
	// Elsewhere in a list, and a policies that was empty before.
	for before, after := range map[string]string{
		`{"policies": [` + it + `, {"x": 1}]}`:                                   `{"policies": [{"x": 1}]}`,
		`{"policies": [{"x": 1}, ` + it + `, {"y": 2}]}`:                         `{"policies": [{"x": 1}, {"y": 2}]}`,
		"{\"policies\": [\n  " + it + ", // why\n  {\"x\": 1}\n]}":               "{\"policies\": [\n  // why\n  {\"x\": 1}\n]}",
		`{"policies": [` + it + ` /* why */, {"x": 1}]}`:                         `{"policies": [ /* why */ {"x": 1}]}`,
		`{"policies": [` + it + ` /* why */]}`:                                   `{"policies": [ /* why */]}`,
		`{"a": 1, "policies": [` + it + `], "b": 2}`:                             `{"a": 1, "b": 2}`,
		`{"policies": [` + it + `, ` + it + `]}`:                                 `{}`,
		`{"policies": [{"action":"skill.use","effect":"deny","resource":"it"}]}`: `{}`,
		`{"policies": [` + deny("other") + `]}`:                                  `{"policies": [` + deny("other") + `]}`,
	} {
		out, err := edited([]byte(before), "it", false)
		if err != nil || string(out) != after || !only([]byte(before), out, "it", false) {
			t.Errorf("taking out of %q: %q, %v", before, out, err)
		}
	}
	if only([]byte(`{"a": 1, "policies": []}`), []byte(`{"policies": [`+it+`]}`), "it", true) ||
		only([]byte("{ // why\n}"), []byte(`{"policies": [`+it+`]}`), "it", true) {
		t.Error("a lost key or comment passed")
	}
}
