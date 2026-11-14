package api

import (
	"context"
	"crypto/ecdh"
	"crypto/rand"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/types/known/emptypb"

	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/servers"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
	"github.com/afrase/nushi/relay"
)

// deviceListener's connections are a paired device's channel, as remote
// access serves them: each says which device it is.
type deviceListener struct {
	net.Listener
	device string
}

func (l deviceListener) Accept() (net.Conn, error) {
	c, err := l.Listener.Accept()
	if err != nil {
		return nil, err
	}
	return deviceConn{c, l.device}, nil
}

type deviceConn struct {
	net.Conn
	device string
}

func (c deviceConn) Device() string { return c.device }

// asDevice is the devices' API as main serves it (DeviceConn), each call
// on a channel of device.
func asDevice(t *testing.T, h http.Handler, device string) nushiv1connect.NushiServiceClient {
	t.Helper()
	srv := httptest.NewUnstartedServer(h)
	srv.Listener = deviceListener{srv.Listener, device}
	srv.Config.ConnContext = DeviceConn
	srv.Start()
	t.Cleanup(srv.Close)
	return nushiv1connect.NewNushiServiceClient(http.DefaultClient, srv.URL)
}

// A device's own calls act on the device whose channel they came on, and
// on no other: one phone can't unpair another or take its notifications.
func TestADevicesCallsAreItsOwn(t *testing.T) {
	st := store.New(t.TempDir())
	testcheck.NoErr(t, st.SaveDevices([]model.Device{{ID: "d1", Name: "one", Kind: "web"}, {ID: "d2", Name: "two", Kind: "web"}}))
	rs, err := remote.New(st, &relay.Dialer{}, func(net.Conn) {}, func() func() { return func() {} }, func(model.Event) {})
	testcheck.NoErr(t, err)
	t.Cleanup(rs.Close)
	rs.UsePush(remote.Push{Key: "key"}, false)
	c := asDevice(t, ForDevices(Services{Remote: rs}), "d1")
	ctx := context.Background()

	k, err := ecdh.P256().GenerateKey(rand.Reader)
	testcheck.NoErr(t, err)
	sub := &nushiv1.SetPushSubscriptionRequest{Endpoint: "https://web.push.apple.com/QGuQyav", P256Dh: k.PublicKey().Bytes(), Auth: make([]byte, 16)}
	if _, err := c.SetPushSubscription(ctx, connect.NewRequest(sub)); err != nil {
		t.Fatal(err)
	}
	pushed := func(id string) bool {
		i := slices.IndexFunc(rs.Get().Devices, func(d model.Device) bool { return d.ID == id })
		return i >= 0 && rs.Get().Devices[i].Push != nil
	}
	if !pushed("d1") || pushed("d2") {
		t.Errorf("the subscription: d1 %v, d2 %v; want d1's only", pushed("d1"), pushed("d2"))
	}

	if _, err := c.UnpairThisDevice(ctx, connect.NewRequest(&nushiv1.UnpairThisDeviceRequest{})); err != nil {
		t.Fatal(err)
	}
	var left []string
	for _, d := range rs.Get().Devices {
		left = append(left, d.ID)
	}
	if !slices.Equal(left, []string{"d2"}) {
		t.Errorf("after d1 unpaired itself: %v", left)
	}
}

// deviceMay is every call a paired device's channel makes: a new call is
// either here or in macOnly, so what a phone may do is a decision, not a
// default.
var deviceMay = []string{
	"Ping", "ListChats", "GetChat", "GetChatItems", "GetChatImage", "StartChat", "ListAgents", "SetUpAgent", "RemoveAgent",
	"ListAgentSessions", "OpenAgentSession", "SearchAgentSessions", "MoveChat", "SendPrompt", "RewindChat", "Unqueue",
	"CancelTurn", "StopTask", "ForkChat", "CloseSideChat", "ForkAsChat", "KeepSideChat", "ArchiveSideChat",
	"RestoreSideChat", "RenameChat", "PinChats", "SetChatColor", "PinMessage", "RenameBranch", "SwitchBranch",
	"ArchiveChat", "SleepChat", "ReopenChat", "GetMemory",
	"GetSettings", "SetSettings", "ListTranscripts", "ClearTranscripts", "PlanDeleteChat", "DeleteChat",
	"DismissRemovedChats", "AnswerPermission", "AnswerQuestion", "SetConfigOption", "GetDiff", "GetFile",
	"WatchChatFile", "FindChatFiles", "WatchChatFolder", "ListCommits", "GetFolderStatus", "GetRelatedWorktrees",
	"GetRelatedWorktreeStats", "ListBranches", "ListFiles", "GetContextUsage", "ListMcpServers", "AddMcpServer",
	"EditMcpServer", "RemoveMcpServer", "SetMcpServerOn", "LoginMcpServer", "LogoutMcpServer", "ListSkills",
	"SetSkillOn", "SetPluginOn", "UninstallPlugin", "TrashSkill", "LinkSkill", "ReloadChat", "OpenTerminal",
	"ListTerminals", "AttachTerminal", "WriteTerminal", "ResizeTerminal", "RenameTerminal", "ArrangeTerminals",
	"RestartTerminal", "CloseTerminal", "CheckFolder", "TrustFolder", "GetRemote", "GetPushKey",
	"SetPushSubscription", "SetDeviceView", "UnpairThisDevice", "Log", "ListJiraSites", "AddJiraSite",
	"RemoveJiraSite", "CheckJiraSite", "ListJiraBoards", "SetJiraBoard", "SetJiraSearches", "ListJiraIssues",
	"GetJiraJql", "SuggestJiraJql", "GetJiraIssue", "ListJiraTransitions", "TransitionJiraIssue", "AddJiraComment",
	"FindJiraIssues", "GetJiraAttachment", "ListGitHubHosts", "AddGitHubToken", "RemoveGitHubToken",
	"ListGitHubRepos", "ListGitHubInbox", "GetGitHubStates", "GetGitHubItems", "GetGitHubPull", "GetGitHubIssue", "GetGitHubFiles",
	"GetGitHubJobLog", "ReplyGitHubThread", "ResolveGitHubThread", "AddGitHubComment", "SubmitGitHubReview",
	"RerunGitHubChecks", "GetGitHubMergeText", "MergeGitHubPull", "EnableGitHubAutoMerge", "DisableGitHubAutoMerge",
	"EnqueueGitHubPull", "DequeueGitHubPull", "GetCleanUp", "RemoveChatWorktree", "DeleteChatBranch",
	"DeleteGitHubBranch", "RestoreGitHubBranch", "FindChatPull", "LinkChatPull", "Events",
}

// Every call of the API is either the Mac's only or reviewed as one a
// device may make, and a device's channel refuses each of the Mac's,
// streaming ones too, before its handler runs.
func TestEveryCallIsDecidedForDevices(t *testing.T) {
	methods := nushiv1.File_nushi_v1_nushi_proto.Services().ByName("NushiService").Methods()
	srv := httptest.NewServer(ForDevices(Services{}))
	t.Cleanup(srv.Close)
	ctx := context.Background()
	seen := map[string]bool{}
	for i := range methods.Len() {
		m := methods.Get(i)
		name := string(m.Name())
		seen[name] = true
		proc := "/" + nushiv1connect.NushiServiceName + "/" + name
		may := slices.Contains(deviceMay, name)
		if may == macOnly[proc] {
			t.Errorf("%s: in macOnly %v, in deviceMay %v; it must be in exactly one", name, macOnly[proc], may)
		}
		if !macOnly[proc] {
			continue
		}
		c := connect.NewClient[emptypb.Empty, emptypb.Empty](http.DefaultClient, srv.URL+proc)
		var err error
		if m.IsStreamingServer() {
			var s *connect.ServerStreamForClient[emptypb.Empty]
			s, err = c.CallServerStream(ctx, connect.NewRequest(&emptypb.Empty{}))
			if err == nil {
				for s.Receive() {
				}
				err = s.Err()
				_ = s.Close()
			}
		} else {
			_, err = c.CallUnary(ctx, connect.NewRequest(&emptypb.Empty{}))
		}
		var ce *connect.Error
		if !errors.As(err, &ce) || ce.Code() != connect.CodePermissionDenied || ce.Message() != "only the Mac can do this" {
			t.Errorf("%s from a device: %v, want the guard's refusal", name, err)
		}
	}
	for _, name := range deviceMay {
		if !seen[name] {
			t.Errorf("deviceMay names %s, which the API doesn't have", name)
		}
	}
}

// The dev servers run on the Mac's word only: past the devices' guard,
// each call checks it came on the Mac's socket, so a way in that forgets
// the guard still can't run a launch file's command.
func TestOnlyTheMacRunsDevServers(t *testing.T) {
	c := client(t, serve(Services{Servers: &servers.Service{}}, "device"))
	ctx := context.Background()
	for name, call := range map[string]func() error{
		"ListServers": func() error {
			_, err := c.ListServers(ctx, connect.NewRequest(&nushiv1.ListServersRequest{ChatId: "c"}))
			return err
		},
		"StartServer": func() error {
			_, err := c.StartServer(ctx, connect.NewRequest(&nushiv1.StartServerRequest{ChatId: "c"}))
			return err
		},
		"StopServer": func() error {
			_, err := c.StopServer(ctx, connect.NewRequest(&nushiv1.StopServerRequest{ChatId: "c"}))
			return err
		},
		"StopAllServers": func() error {
			_, err := c.StopAllServers(ctx, connect.NewRequest(&nushiv1.StopAllServersRequest{ChatId: "c"}))
			return err
		},
		"WatchServerLog": func() error {
			s, err := c.WatchServerLog(ctx, connect.NewRequest(&nushiv1.WatchServerLogRequest{ChatId: "c"}))
			if err != nil {
				return err
			}
			defer func() { _ = s.Close() }()
			for s.Receive() {
			}
			return s.Err()
		},
	} {
		if err := call(); connect.CodeOf(err) != connect.CodePermissionDenied || !strings.Contains(err.Error(), "only the Mac runs dev servers") {
			t.Errorf("%s from a device, unguarded: %v", name, err)
		}
	}
}
