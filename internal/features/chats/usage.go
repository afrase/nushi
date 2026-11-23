package chats

import (
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// Meter takes what each turn used and the account limits agents report
// (internal/features/usage, ADR 0136). Neither call may wait: they are made
// under the chat's lock.
type Meter interface {
	Turn(model.TurnUsage)
	Limits(agent string, limits []model.Limit)
}

// usageMetaLocked takes what a usage report's _meta says: the model, and
// the account's limits, which go to the meter at once.
func (c *chat) usageMetaLocked(meta map[string]any) {
	r := c.kind.usageReader
	if r == nil || len(meta) == 0 {
		return
	}
	if m := r.UsageModel(meta); m != "" {
		c.usageModel = m
	}
	if l := r.Limits(meta); len(l) > 0 && c.svc.meter != nil {
		now := time.Now()
		for i := range l {
			l[i].Seen = now
		}
		c.svc.meter.Limits(c.kind.Name, l)
	}
}

// meterLocked tells the meter a turn ended: its tokens, from the prompt's
// answer (nil when there's none: a turn of the agent's own, or the end of
// a held turn's work), and the session's cost as the agent last reported
// it. A side chat's turns count toward its chat.
func (c *chat) meterLocked(end model.UsageEnd, u *acp.Usage) {
	m := c.svc.meter
	if m == nil {
		return
	}
	t := model.TurnUsage{At: time.Now(), Chat: c.id, Meter: c.id, From: c.costFrom, Began: c.record.Created, Agent: c.kind.Name,
		Model: c.modelLocked(), Folder: c.record.ProjectFolder(), End: end, Total: c.usage.Cost, Currency: c.usage.Currency, Costed: c.costed}
	if c.parent != nil {
		t.Chat, t.Side, t.Folder = c.parent.id, true, c.project
	}
	if u != nil {
		t.Input, t.Output = int64(u.InputTokens), int64(u.OutputTokens) //nolint:gosec // token counts, far below the limits
		t.CacheRead, t.CacheWrite = tokens(u.CachedReadTokens), tokens(u.CachedWriteTokens)
	}
	m.Turn(t)
}

// modelLocked is the model the chat's turns run on: what the agent's usage
// last named, else the chat's model option's value; "" when neither says.
func (c *chat) modelLocked() string {
	if c.usageModel != "" {
		return c.usageModel
	}
	for _, o := range c.config {
		if o.Category == "model" {
			return o.Current
		}
	}
	return ""
}

// promptUsage is a turn's tokens from the prompt's answer; nil when it
// failed or said none.
func promptUsage(resp *acp.PromptResponse, err error) *acp.Usage {
	if err != nil || resp == nil {
		return nil
	}
	return resp.Usage
}
