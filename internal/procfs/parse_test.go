package procfs

import (
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// boot is testdata/proc-stat's btime.
var boot = time.Unix(1793405909, 0)

// The samples in testdata/stat are real lines (cat, systemd) and made-up
// ones shaped as the kernel writes them: a comm holding ") (" and spaces,
// one holding a newline, a kernel thread, a zombie, and broken lines.
func TestParseStat(t *testing.T) {
	at := func(ticks int64) time.Time { return boot.Add(time.Duration(ticks) * 10 * time.Millisecond) }
	for _, tc := range []struct {
		file string
		want Stat // zero: an error
	}{
		{"cat", Stat{Pid: 53695, Ppid: 53477, Pgid: 8, Session: 8, State: 'R', Comm: "cat", Started: at(70323525)}},
		{"systemd", Stat{Pid: 1, Pgid: 1, Session: 1, State: 'S', Comm: "systemd", Started: at(69168466)}},
		{"odd-comm", Stat{Pid: 4242, Ppid: 4200, Pgid: 4242, Session: 4100, TTY: 34816, State: 'S', Comm: "a) (b c)", Started: at(70400000)}},
		{"newline-comm", Stat{Pid: 777, Ppid: 1, Pgid: 777, Session: 777, State: 'S', Comm: "two\nlines", Started: at(1000)}},
		{"kworker", Stat{Pid: 57, Ppid: 2, State: 'I', Comm: "kworker/3:1-events", Started: at(150)}},
		{"zombie", Stat{Pid: 60001, Ppid: 53477, Pgid: 60001, Session: 53477, TTY: 34817, State: 'Z', Comm: "sh", Started: at(70500123)}},
		{"short", Stat{}},
		{"no-parens", Stat{}},
		{"bad-pid", Stat{}},
	} {
		t.Run(tc.file, func(t *testing.T) {
			b, err := os.ReadFile(filepath.Join("testdata", "stat", tc.file))
			testcheck.NoErr(t, err)
			got, err := parseStat(b, boot)
			if tc.want != (Stat{}) {
				tc.want.SinceBoot = tc.want.Started.Sub(boot)
			}
			switch {
			case tc.want == Stat{} && err == nil:
				t.Fatalf("parsed %+v, want an error", got)
			case tc.want != Stat{} && err != nil:
				t.Fatal(err)
			case got != tc.want:
				t.Fatalf("got %+v\nwant %+v", got, tc.want)
			}
		})
	}
}

// The start time is boot plus ticks of 10 ms, cut to the second as ps's
// lstart shows it: cat's 70323525 ticks are 703235.25 s after boot.
func TestStartedAsLstart(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("testdata", "stat", "cat"))
	testcheck.NoErr(t, err)
	s, err := parseStat(b, boot)
	testcheck.NoErr(t, err)
	if got, want := s.Started.Truncate(time.Second), time.Unix(1793405909+703235, 0); !got.Equal(want) {
		t.Fatalf("started %v, want %v", got, want)
	}
	if want := 703235*time.Second + 250*time.Millisecond; s.SinceBoot != want {
		t.Fatalf("since boot %v, want %v", s.SinceBoot, want)
	}
}

// A clock step moves btime, and Started with it, but not SinceBoot.
func TestClockStep(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("testdata", "stat", "cat"))
	testcheck.NoErr(t, err)
	before, err := parseStat(b, boot)
	testcheck.NoErr(t, err)
	after, err := parseStat(b, boot.Add(2*time.Second))
	testcheck.NoErr(t, err)
	if after.Started.Sub(before.Started) != 2*time.Second || after.SinceBoot != before.SinceBoot {
		t.Fatalf("before %+v\nafter %+v", before, after)
	}
}

func TestParseBootTime(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("testdata", "proc-stat"))
	testcheck.NoErr(t, err)
	got, err := parseBootTime(b)
	testcheck.NoErr(t, err)
	if !got.Equal(boot) {
		t.Fatalf("boot %v, want %v", got, boot)
	}
	b, err = os.ReadFile(filepath.Join("testdata", "proc-stat-no-btime"))
	testcheck.NoErr(t, err)
	if got, err := parseBootTime(b); err == nil {
		t.Fatalf("no btime parsed as %v", got)
	}
}

func TestSplitCmdline(t *testing.T) {
	for _, tc := range []struct {
		in   string
		want []string
	}{
		{"/bin/sh\x00-c\x00sleep 30; echo made-up\x00", []string{"/bin/sh", "-c", "sleep 30; echo made-up"}},
		{"\x0030\x00", []string{"", "30"}},               // an empty first argument
		{"node\x00\x00x\x00", []string{"node", "", "x"}}, // an empty one between
		{"nginx: worker process", []string{"nginx: worker process"}},
		{"", []string{}}, // a kernel thread's
		// Retitled by libuv: the title, then NULs to the old arguments' end.
		{"claude\x00\x00\x00\x00\x00\x00\x00", []string{"claude"}},
		{"\x00", []string{""}},
	} {
		if got := splitCmdline([]byte(tc.in)); !slices.Equal(got, tc.want) {
			t.Errorf("%q: got %q, want %q", tc.in, got, tc.want)
		}
	}
}
