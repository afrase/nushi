package store

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// devices.json still says each device is the web app, for a daemon before
// v0.53 reading it after a downgrade: it sends the kind it reads, and its
// app labels a device without one "iPhone app".
func TestDevicesKeepTheirKindForAnOlderDaemon(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	testcheck.NoErr(t, s.SaveDevices([]model.Device{{ID: "a", Name: "Phone"}}))
	data, err := os.ReadFile(filepath.Join(dir, "devices.json"))
	testcheck.NoErr(t, err)
	if !strings.Contains(string(data), `"kind": "web"`) {
		t.Errorf("no kind:\n%s", data)
	}
	got, err := s.Devices()
	testcheck.NoErr(t, err)
	if len(got) != 1 || got[0].ID != "a" || got[0].Name != "Phone" {
		t.Errorf("read back %+v", got)
	}
}
