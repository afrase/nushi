package e2e

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/tools"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// fakeServerBin builds the servers feature's fake dev server.
func fakeServerBin(t *testing.T) string {
	t.Helper()
	bin := filepath.Join(t.TempDir(), "fakeserver")
	if out, err := exec.Command("go", "build", "-o", bin, "../features/servers/testdata/fakeserver").CombinedOutput(); err != nil {
		t.Fatalf("building the fake server: %v\n%s", err, out)
	}
	return bin
}

// freePort is a port nothing listens on now.
func freePort(t *testing.T) int {
	t.Helper()
	ln, err := net.Listen("tcp4", "127.0.0.1:0")
	testcheck.NoErr(t, err)
	defer ln.Close() //nolint:errcheck // a probe
	return ln.Addr().(*net.TCPAddr).Port
}

// A chat's folder's launch file lists its server, which starts on the
// Mac's word, says so as an event, and stops when the folder's last chat
// is archived; a paired device can do none of it (ADR 0098).
func TestDevServers(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	port := freePort(t)
	testcheck.Write(t, filepath.Join(repo, ".agents", "launch.json"),
		fmt.Sprintf(`{"configurations": [{"name": "web", "runtimeExecutable": %q, "port": %d}]}`, fakeServerBin(t), port))
	d := startDaemon(t, t.TempDir(), nil)
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: repo})
	list := must(a.c.ListServers(ctx, connect.NewRequest(&nushiv1.ListServersRequest{ChatId: id})))
	if len(list.Servers) != 1 || list.Servers[0].Name != "web" || list.Servers[0].State != nushiv1.DevServerState_DEV_SERVER_STATE_STOPPED {
		t.Fatalf("ListServers = %v", list)
	}
	hash := list.Servers[0].Hash
	phone := openAt(t, d.devices)
	if _, err := phone.c.StartServer(ctx, connect.NewRequest(&nushiv1.StartServerRequest{ChatId: id, Entry: &nushiv1.StartServerRequest_Index{Index: 0}, Hash: hash})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("a device started a server: %v", err)
	}
	if _, err := a.c.StartServer(ctx, connect.NewRequest(&nushiv1.StartServerRequest{ChatId: id, Entry: &nushiv1.StartServerRequest_Name{Name: "web"}})); connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Errorf("a start without the entry's hash: %v", err)
	}
	must(a.c.StartServer(ctx, connect.NewRequest(&nushiv1.StartServerRequest{ChatId: id, Entry: &nushiv1.StartServerRequest_Name{Name: "web"}, Hash: hash})))
	a.waitFor("the server's change", func(e *nushiv1.EventsResponse) bool { return e.GetServersChanged() == repo })
	until(t, "the server to answer", func() bool {
		s := must(a.c.ListServers(ctx, connect.NewRequest(&nushiv1.ListServersRequest{ChatId: id}))).Servers[0]
		return s.State == nushiv1.DevServerState_DEV_SERVER_STATE_RUNNING && s.Url == fmt.Sprintf("http://localhost:%d", port)
	})
	must(a.c.ArchiveChat(ctx, connect.NewRequest(&nushiv1.ArchiveChatRequest{ChatId: id, Archived: true})))
	until(t, "the server to stop", func() bool {
		c, err := net.Dial("tcp4", fmt.Sprintf("127.0.0.1:%d", port))
		if err == nil {
			_ = c.Close()
		}
		return err != nil
	})
}

// A chat's agent runs its folder's server by name through Nushi's tools:
// once it answers, the Mac is asked to show its page beside that chat;
// its log follows it on the Mac, never on a device (ADR 0100).
func TestAgentRunsADevServer(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	port := freePort(t)
	testcheck.Write(t, filepath.Join(repo, ".agents", "launch.json"),
		fmt.Sprintf(`{"configurations": [{"name": "web", "runtimeExecutable": %q, "port": %d}]}`, fakeServerBin(t), port))
	d := startDaemon(t, t.TempDir(), nil)
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: repo})
	key := d.tools.Key(tools.Grant{Chat: id, Agent: "fake"})
	text, failed := callTool(t, d, key, "preview_list", map[string]any{})
	var list struct {
		Servers []struct{ Name, State string }
	}
	if failed || json.Unmarshal([]byte(text), &list) != nil || len(list.Servers) != 1 || list.Servers[0].Name != "web" || list.Servers[0].State != "stopped" {
		t.Fatalf("preview_list: %q, failed %v", text, failed)
	}
	url := fmt.Sprintf("http://localhost:%d", port)
	if text, failed = callTool(t, d, key, "preview_start", map[string]string{"name": "web"}); failed || !strings.Contains(text, url) {
		t.Fatalf("preview_start: %q", text)
	}
	e := a.waitFor("the server's page", func(e *nushiv1.EventsResponse) bool { return e.GetShowUrl() != "" })
	if e.ChatId != id || e.GetShowUrl() != url {
		t.Errorf("event %+v", e)
	}
	row := must(a.c.ListServers(ctx, connect.NewRequest(&nushiv1.ListServersRequest{ChatId: id}))).Servers[0]
	if row.State != nushiv1.DevServerState_DEV_SERVER_STATE_RUNNING || row.LogId == "" || row.LogId != row.ServerId {
		t.Fatalf("row %v", row)
	}
	phone := openAt(t, d.devices)
	ps, err := phone.c.WatchServerLog(ctx, connect.NewRequest(&nushiv1.WatchServerLogRequest{ChatId: id, ServerId: row.LogId}))
	testcheck.NoErr(t, err)
	if ps.Receive() || connect.CodeOf(ps.Err()) != connect.CodePermissionDenied {
		t.Errorf("a device watched a server's log: %v", ps.Err())
	}
	_ = ps.Close()
	stream, err := a.c.WatchServerLog(ctx, connect.NewRequest(&nushiv1.WatchServerLogRequest{ChatId: id, ServerId: row.LogId}))
	testcheck.NoErr(t, err)
	defer func() { _ = stream.Close() }()
	var log strings.Builder
	for !strings.Contains(log.String(), fmt.Sprintf("listening on %d", port)) {
		if !stream.Receive() {
			t.Fatalf("the log ended: %q, %v", log.String(), stream.Err())
		}
		log.Write(stream.Msg().Data)
	}
	if text, failed = callTool(t, d, key, "preview_logs", map[string]string{"name": "web"}); failed || !strings.Contains(text, "fakeserver starting") {
		t.Errorf("preview_logs: %q", text)
	}
	if text, failed = callTool(t, d, key, "preview_stop", map[string]string{"name": "web"}); failed || text != "Stopped web." {
		t.Errorf("preview_stop: %q", text)
	}
	for stream.Receive() {
		if stream.Msg().Ended {
			return
		}
	}
	t.Errorf("the log never said it ended: %v", stream.Err())
}
