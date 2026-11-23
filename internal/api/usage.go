package api

import (
	"context"
	"errors"
	"maps"
	"slices"
	"time"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

// Usage sums what the chats' turns used (internal/features/usage, ADR
// 0136).
type Usage interface {
	// Report sums the turns that ended from from on (zero: all of them),
	// days counted in the daemon's time zone.
	Report(ctx context.Context, from time.Time) (model.UsageReport, error)
}

var errNoUsage = errors.New("this daemon doesn't keep usage")

// GetUsage is this computer's only (macOnly): the page names project
// folders and chats' titles, and the phone has none.
func (s *server) GetUsage(ctx context.Context, req *connect.Request[nushiv1.GetUsageRequest]) (*connect.Response[nushiv1.GetUsageResponse], error) {
	m := req.Msg
	if s.Usage == nil {
		return nil, connect.NewError(connect.CodeUnimplemented, errNoUsage)
	}
	r, err := s.Usage.Report(ctx, msTime(m.From))
	if err != nil {
		return nil, refused(err) // not Unavailable: the app takes that for the daemon gone
	}
	return connect.NewResponse(reportProto(r)), nil
}

// msTime is a time the API gives in ms; 0 is none.
func msTime(ms int64) time.Time {
	if ms == 0 {
		return time.Time{}
	}
	return time.UnixMilli(ms)
}

func reportProto(r model.UsageReport) *nushiv1.GetUsageResponse {
	out := &nushiv1.GetUsageResponse{Totals: totalsProto(r.Totals), Days: groupsProto(r.Days), Agents: groupsProto(r.Agents), Models: groupsProto(r.Models),
		Folders: groupsProto(r.Folders), NoCost: r.NoCost, Earliest: unixMs(r.Earliest)}
	for _, c := range r.Chats {
		out.Chats = append(out.Chats, &nushiv1.UsageChat{ChatId: c.ID, Title: c.Title, Agent: c.Agent, Totals: totalsProto(c.UsageTotals)})
	}
	for _, l := range r.Limits {
		out.Limits = append(out.Limits, &nushiv1.UsageLimit{Agent: l.Agent, Kind: l.Kind, Status: l.Status, Utilization: l.Utilization,
			ResetsAt: unixMs(l.ResetsAt), Seen: unixMs(l.Seen)})
	}
	return out
}

func groupsProto(gs []model.UsageGroup) []*nushiv1.UsageGroup {
	out := make([]*nushiv1.UsageGroup, 0, len(gs))
	for _, g := range gs {
		out = append(out, &nushiv1.UsageGroup{Key: g.Key, Totals: totalsProto(g.UsageTotals)})
	}
	return out
}

func totalsProto(t model.UsageTotals) *nushiv1.UsageTotals {
	out := &nushiv1.UsageTotals{InputTokens: t.Input, OutputTokens: t.Output, CacheReadTokens: t.CacheRead, CacheWriteTokens: t.CacheWrite, Turns: t.Turns}
	for _, c := range slices.Sorted(maps.Keys(t.Cost)) {
		out.Cost = append(out.Cost, &nushiv1.UsageCost{Currency: c, Amount: t.Cost[c]})
	}
	return out
}
