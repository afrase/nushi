package store

import (
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// The sessions are read once, then kept as they're saved and deleted: a
// file changed behind the store isn't read again, and a save that
// couldn't be written isn't kept.
func TestSessionsKept(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	titles := func() []string {
		t.Helper()
		got, err := s.Sessions()
		testcheck.NoErr(t, err)
		var out []string
		for _, sess := range got {
			out = append(out, sess.ID+":"+sess.Title)
		}
		return out
	}
	testcheck.NoErr(t, s.SaveSession(model.ChatRecord{ID: "b", Title: "B"})) // before the first read
	if got := titles(); !slices.Equal(got, []string{"b:B"}) {
		t.Fatalf("read: %q", got)
	}
	testcheck.NoErr(t, s.SaveSession(model.ChatRecord{ID: "a", Title: "A"}))
	testcheck.NoErr(t, s.SaveSession(model.ChatRecord{ID: "b", Title: "B2"}))
	testcheck.NoErr(t, os.WriteFile(filepath.Join(dir, "sessions", "c.json"), []byte(`{"ID":"c"}`), 0o600))
	if got := titles(); !slices.Equal(got, []string{"a:A", "b:B2"}) {
		t.Errorf("saved: %q", got)
	}
	testcheck.NoErr(t, s.DeleteSession("a"))
	if err := s.DeleteSession("a"); err == nil {
		t.Error("deleted a session that was gone")
	}
	testcheck.NoErr(t, os.Chmod(filepath.Join(dir, "sessions"), 0o500)) // its new file can't be made
	t.Cleanup(func() { _ = os.Chmod(filepath.Join(dir, "sessions"), 0o700) })
	if err := s.SaveSession(model.ChatRecord{ID: "b", Title: "B3"}); err == nil {
		t.Fatal("wrote in a folder it can't")
	}
	if got := titles(); !slices.Equal(got, []string{"b:B2"}) {
		t.Errorf("deleted, then a failed save: %q", got)
	}
	testcheck.NoErr(t, os.Chmod(filepath.Join(dir, "sessions"), 0o700))
	if got, err := New(dir).Sessions(); err != nil || len(got) != 2 { // b and c, from the files
		t.Errorf("a new store: %+v, %v", got, err)
	}
}

// A file's HasMessages is the session's, read in the one decode; one
// without it is worked out (TestOldAndBrokenSessionFiles).
func TestSessionsHasMessages(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	s.HadMessages = func(model.ChatRecord) bool { return true }
	if err := os.MkdirAll(filepath.Join(dir, "sessions"), 0o700); err != nil {
		t.Fatal(err)
	}
	for name, body := range map[string]string{
		"said.json":   `{"ID":"said","HasMessages":true}`,
		"titled.json": `{"ID":"titled","Title":"T","HasMessages":false}`,
	} {
		if err := os.WriteFile(filepath.Join(dir, "sessions", name), []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	got, err := s.Sessions()
	if err != nil || len(got) != 2 || !got[0].HasMessages || got[1].HasMessages {
		t.Errorf("sessions = %+v, %v", got, err)
	}
}

// A session handed out or saved shares nothing with what's kept, so a
// caller changing its copy in place changes nobody else's.
func TestSessionsShareNothing(t *testing.T) {
	var sess model.ChatRecord
	v := reflect.ValueOf(&sess).Elem()
	var shared []int // the fields clone copies
	for field := range v.Type().Fields() {
		i := field.Index[0]
		f := v.Field(i)
		switch f.Kind() {
		case reflect.Pointer:
			f.Set(reflect.New(f.Type().Elem()))
		case reflect.Slice:
			f.Set(reflect.MakeSlice(f.Type(), 1, 1))
		case reflect.Map:
			f.Set(reflect.MakeMap(f.Type()))
		default:
			if f.Type() != reflect.TypeFor[time.Time]() && refs(f.Type()) { // a Time is a value
				t.Errorf("%s holds references clone doesn't copy", field.Name)
			}
			continue
		}
		if elem := f.Type().Elem(); refs(elem) {
			t.Errorf("%s: its %s holds references clone doesn't copy", field.Name, elem)
		}
		shared = append(shared, i)
	}
	c := reflect.ValueOf(clone(sess))
	for _, i := range shared {
		if f, g := v.Field(i), c.Field(i); g.IsNil() || f.UnsafePointer() == g.UnsafePointer() {
			t.Errorf("%s is shared (or lost)", v.Type().Field(i).Name)
		}
	}
	if !reflect.DeepEqual(clone(model.ChatRecord{}), model.ChatRecord{}) {
		t.Error("an empty session's clone isn't empty")
	}
}

// refs says whether a value of t holds a pointer, slice, map, or the like.
func refs(t reflect.Type) bool {
	switch t.Kind() {
	case reflect.Pointer, reflect.Slice, reflect.Map, reflect.Interface, reflect.Chan, reflect.Func, reflect.UnsafePointer:
		return true
	case reflect.Struct:
		for f := range t.Fields() {
			if refs(f.Type) {
				return true
			}
		}
	case reflect.Array:
		return refs(t.Elem())
	default:
	}
	return false
}
