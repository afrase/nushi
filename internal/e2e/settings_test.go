package e2e

import (
	"context"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// A SetSettings with one field refused changes nothing: every field is
// checked before any is written, and the rest go in one write.
func TestSetSettingsRefusedWritesNothing(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	get := func() *nushiv1.Settings {
		t.Helper()
		return must(a.c.GetSettings(ctx, connect.NewRequest(&nushiv1.GetSettingsRequest{}))).Settings
	}
	off, days := false, int32(-1)
	_, err := a.c.SetSettings(ctx, connect.NewRequest(&nushiv1.SetSettingsRequest{Settings: &nushiv1.Settings{SleepAfterMinutes: 15, KeepTranscripts: &off, TranscriptDays: &days}}))
	if connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Fatalf("a negative transcript_days: %v", err)
	}
	if got := get(); got.SleepAfterMinutes != 30 || !got.GetKeepTranscripts() || got.GetTranscriptDays() != 0 {
		t.Errorf("refused, yet written: %v", got)
	}
	days = 7
	must(a.c.SetSettings(ctx, connect.NewRequest(&nushiv1.SetSettingsRequest{Settings: &nushiv1.Settings{SleepAfterMinutes: 15, KeepTranscripts: &off, TranscriptDays: &days}})))
	if got := get(); got.SleepAfterMinutes != 15 || got.GetKeepTranscripts() || got.GetTranscriptDays() != 7 {
		t.Errorf("written: %v", got)
	}
}
