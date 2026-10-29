package claudetest

import (
	"bufio"
	"context"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/afrase/nushi/claudeagent"
)

const cassette = `{"argv":["--output-format","stream-json","--session-id=rec-s"],"envKeys":["PATH"],"cli":"2.1.312"}
{"dir":"in","ms":0,"frame":{"type":"control_request","request_id":"rec-r","request":{"subtype":"initialize","hooks":{}}}}
{"dir":"out","ms":5,"frame":{"type":"control_response","response":{"subtype":"success","request_id":"rec-r","response":{}}}}
{"dir":"in","ms":6,"frame":{"type":"keep_alive"}}

{"dir":"in","ms":7,"frame":{"type":"user","uuid":"rec-u","session_id":"","message":{"role":"user","content":"hi"}}}
{"dir":"out","ms":9,"frame":{"type":"user","uuid":"rec-u","session_id":"rec-s","isReplay":true}}
{"dir":"out","ms":20,"frame":{"type":"result","subtype":"success","session_id":"rec-s","user_message_uuids":["rec-u"],"result":"rec-u was here"}}
`

// A replay expects what the client writes and writes what claude wrote,
// with the client's ids for the recorded session, request and message;
// an id inside other text stays.
func TestReplay(t *testing.T) {
	c, err := ReadCassette(strings.NewReader(cassette))
	if err != nil {
		t.Fatal(err)
	}
	if c.Header.CLI != "2.1.312" || len(c.Frames) != 6 {
		t.Fatalf("%+v", c)
	}
	f := Replay(c)
	p, err := f.Spawn(context.Background(), claudeagent.Spec{Path: "/claude", Args: []string{"--session-id", "live-s"}})
	if err != nil {
		t.Fatal(err)
	}
	go func() { _, _ = io.Copy(io.Discard, p.Stderr) }()
	t.Cleanup(func() {
		_ = p.Signal(os.Kill)
		<-f.Exited()
	})
	s := started{Proc: p, lines: bufio.NewScanner(p.Stdout)}
	s.write(t, `{"type":"control_request","request_id":"req_1","request":{"subtype":"initialize"}}`)
	if got := s.read(t); got != `{"type":"control_response","response":{"subtype":"success","request_id":"req_1","response":{}}}` {
		t.Errorf("%s", got)
	}
	s.write(t, `{"type":"user","uuid":"u-live","message":{"role":"user","content":"hello"}}`)
	for _, want := range []string{
		`{"type":"user","uuid":"u-live","session_id":"live-s","isReplay":true}`,
		`{"type":"result","subtype":"success","session_id":"live-s","user_message_uuids":["u-live"],"result":"rec-u was here"}`,
	} {
		if got := s.read(t); got != want {
			t.Errorf("got  %s\nwant %s", got, want)
		}
	}
	<-f.Played()
	_ = p.Stdin.Close()
	if err := p.Wait(); err != nil || f.Err() != nil {
		t.Errorf("exit %v, script %v", err, f.Err())
	}
}

// A line that isn't what was recorded fails the replay.
func TestReplayMismatch(t *testing.T) {
	c, err := ReadCassette(strings.NewReader(cassette))
	if err != nil {
		t.Fatal(err)
	}
	f := Replay(c)
	s := start(t, f)
	s.write(t, `{"type":"user","uuid":"u","message":{"role":"user","content":"too soon"}}`)
	if err := s.Wait(); err == nil || f.Err() == nil || !strings.Contains(f.Err().Error(), "too soon") {
		t.Errorf("exit %v, script %v", err, f.Err())
	}
}

func TestReadCassetteRefuses(t *testing.T) {
	for name, text := range map[string]string{
		"empty":     "",
		"no header": `{"dir":"in","frame":{"type":"user"}}`,
		"bad dir":   `{"argv":[]}` + "\n" + `{"dir":"up","frame":{"type":"user"}}`,
		"no frame":  `{"argv":[]}` + "\n" + `{"dir":"in"}`,
	} {
		if _, err := ReadCassette(strings.NewReader(text)); err == nil {
			t.Errorf("%s: read", name)
		}
	}
}
