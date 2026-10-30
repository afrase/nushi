package claudeacp

import (
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// Plan mode's two tools ask in words of their own. EnterPlanMode asks to
// plan first; ExitPlanMode shows the plan and asks to start, in which
// mode, or to keep planning, which stops the turn so the user can say
// what to change.

// ExitPlanMode's options, by id, besides optReject (keep planning).
const (
	optPlanAuto   = "exit-plan-auto"
	optPlanEdits  = "exit-plan-accept-edits"
	optPlanManual = "exit-plan-default"
)

// planModes are the modes ExitPlanMode's options start the work in.
var planModes = map[string]claudeagent.PermissionMode{
	optPlanAuto:   claudeagent.Auto,
	optPlanEdits:  claudeagent.AcceptEdits,
	optPlanManual: claudeagent.PermissionDefault,
}

var enterPlanOptions = []acp.PermissionOption{
	{OptionID: optAllowOnce, Name: "Yes, plan first", Kind: acp.PermissionOptionKindAllowOnce},
	{OptionID: optReject, Name: "No, start now", Kind: acp.PermissionOptionKindRejectOnce},
}

// exitPlanOptions are ExitPlanMode's: Auto mode only on a model that has
// it.
func (s *session) exitPlanOptions() []acp.PermissionOption {
	s.cfg.mu.Lock()
	m := s.cfg.modelInfo()
	auto := m == nil || m.SupportsAutoMode
	s.cfg.mu.Unlock()
	var opts []acp.PermissionOption
	if auto {
		opts = append(opts, acp.PermissionOption{OptionID: optPlanAuto, Name: "Yes, in Auto mode", Kind: acp.PermissionOptionKindAllowAlways})
	}
	return append(opts,
		acp.PermissionOption{OptionID: optPlanEdits, Name: "Yes, accepting edits", Kind: acp.PermissionOptionKindAllowAlways},
		acp.PermissionOption{OptionID: optPlanManual, Name: "Yes, asking before edits", Kind: acp.PermissionOptionKindAllowOnce},
		acp.PermissionOption{OptionID: optReject, Name: "No, keep planning", Kind: acp.PermissionOptionKindRejectOnce},
	)
}

// exitPlan is the user's answer to ExitPlanMode: claude leaves plan mode
// for the mode picked, and the client is told; keeping on planning
// stops the turn, which ends cancelled.
func (s *session) exitPlan(option string) claudeagent.PermissionResult {
	if mode, ok := planModes[option]; ok {
		s.modeChanged(mode)
		return claudeagent.Allow{Classification: claudeagent.UserTemporary,
			UpdatedPermissions: []claudeagent.PermissionUpdate{{Type: claudeagent.UpdateSetMode, Mode: mode, Destination: claudeagent.DestinationSession}}}
	}
	if option != optReject {
		return claudeagent.Deny{Message: "The user cancelled.", Interrupt: true}
	}
	s.mu.Lock()
	if s.active != nil {
		s.active.cancelled = true
	}
	s.mu.Unlock()
	return claudeagent.Deny{Message: "The user wants to keep planning.", Interrupt: true, Classification: claudeagent.UserReject}
}
