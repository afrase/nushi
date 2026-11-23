package e2e

import (
	"context"
	"errors"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// A chat's turns are kept as they end and summed by GetUsage: each turn's
// cost is the session's total less the last, a new process's lower total
// counts whole, and the agent's rate limit is the latest. The phone isn't
// given it.
func TestUsage(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	folder := t.TempDir()
	id := a.start(&nushiv1.StartChatRequest{Folder: folder, Agent: "claude-fake"})
	for _, text := range []string{"title: Spending\nusage", "usage"} {
		a.send(id, text)
		a.waitFor("the turn to end", turnEnded(id))
	}
	before := time.Now()
	u := must(a.c.GetUsage(ctx, connect.NewRequest(&nushiv1.GetUsageRequest{})))
	totals := u.GetTotals()
	if totals.GetTurns() != 2 || len(totals.GetCost()) != 1 || totals.GetCost()[0].GetAmount() != 0.5 || totals.GetCost()[0].GetCurrency() != "USD" ||
		totals.GetInputTokens() != 20 || totals.GetOutputTokens() != 40 || totals.GetCacheReadTokens() != 60 || totals.GetCacheWriteTokens() != 80 {
		t.Errorf("totals %s", testcheck.JSON(t, totals))
	}
	if len(u.GetDays()) != 1 || u.GetDays()[0].GetKey() != time.Now().Format(time.DateOnly) {
		t.Errorf("days %s", testcheck.JSON(t, u.GetDays()))
	}
	key := func(gs []*nushiv1.UsageGroup) string {
		if len(gs) != 1 {
			return ""
		}
		return gs[0].GetKey()
	}
	if key(u.GetAgents()) != "claude-fake" || key(u.GetModels()) != "claude-fake" || key(u.GetFolders()) != folder {
		t.Errorf("agents %s, models %s, folders %s", testcheck.JSON(t, u.GetAgents()), testcheck.JSON(t, u.GetModels()), testcheck.JSON(t, u.GetFolders()))
	}
	if c := u.GetChats(); len(c) != 1 || c[0].GetChatId() != id || c[0].GetTitle() != "Spending" || c[0].GetAgent() != "claude-fake" {
		t.Errorf("chats %s", testcheck.JSON(t, c))
	}
	if l := u.GetLimits(); len(l) != 1 || l[0].GetAgent() != "claude-fake" || l[0].GetKind() != "five_hour" || l[0].GetStatus() != "allowed_warning" ||
		l[0].GetUtilization() != 0.9 || l[0].GetResetsAt() != 1_700_000_000_000 || l[0].GetSeen() == 0 {
		t.Errorf("limits %s", testcheck.JSON(t, l))
	}
	if len(u.GetNoCost()) != 0 || u.GetEarliest() == 0 {
		t.Errorf("no cost %q, earliest %d", u.GetNoCost(), u.GetEarliest())
	}
	if later := must(a.c.GetUsage(ctx, connect.NewRequest(&nushiv1.GetUsageRequest{From: before.UnixMilli()}))); later.GetTotals().GetTurns() != 0 {
		t.Errorf("turns after the range's start: %d", later.GetTotals().GetTurns())
	}

	// After a restart the agent's new process reports 0.25 again: lower than
	// the last total, so all of it is this turn's.
	a = d.reopen(t)
	a.send(id, "usage")
	a.waitFor("the turn to end", turnEnded(id))
	u = must(a.c.GetUsage(ctx, connect.NewRequest(&nushiv1.GetUsageRequest{})))
	if c := u.GetTotals().GetCost(); u.GetTotals().GetTurns() != 3 || len(c) != 1 || c[0].GetAmount() != 0.75 {
		t.Errorf("after a restart: %s", testcheck.JSON(t, u.GetTotals()))
	}

	phone := openAt(t, d.devices)
	_, err := phone.c.GetUsage(ctx, connect.NewRequest(&nushiv1.GetUsageRequest{}))
	if ce := new(connect.Error); !errors.As(err, &ce) || ce.Code() != connect.CodePermissionDenied {
		t.Errorf("the phone's call: %v", err)
	}
}

// An agent that reports no cost is named as such.
func TestUsageWithoutCost(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Folder: t.TempDir()})
	a.send(id, "hello")
	a.waitFor("the turn to end", turnEnded(id))
	u := must(a.c.GetUsage(ctx, connect.NewRequest(&nushiv1.GetUsageRequest{})))
	if u.GetTotals().GetTurns() != 1 || len(u.GetTotals().GetCost()) != 0 || len(u.GetNoCost()) != 1 || u.GetNoCost()[0] != "fake" {
		t.Errorf("usage %s", testcheck.JSON(t, u))
	}
}
