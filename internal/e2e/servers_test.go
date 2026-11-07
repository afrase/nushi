package e2e

import (
	"context"
	"fmt"
	"net"
	"os/exec"
	"path/filepath"
	"testing"

	"connectrpc.com/connect"

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
	phone := openAt(t, d.devices)
	if _, err := phone.c.StartServer(ctx, connect.NewRequest(&nushiv1.StartServerRequest{ChatId: id, Entry: &nushiv1.StartServerRequest_Index{Index: 0}})); connect.CodeOf(err) != connect.CodePermissionDenied {
		t.Errorf("a device started a server: %v", err)
	}
	must(a.c.StartServer(ctx, connect.NewRequest(&nushiv1.StartServerRequest{ChatId: id, Entry: &nushiv1.StartServerRequest_Name{Name: "web"}})))
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
