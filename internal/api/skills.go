package api

import (
	"context"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

func (s *server) ListSkills(ctx context.Context, req *connect.Request[nushiv1.ListSkillsRequest]) (*connect.Response[nushiv1.ListSkillsResponse], error) {
	m := req.Msg
	list, err := s.skills.List(ctx, m.Agent, m.Folder)
	if err != nil {
		return nil, connect.NewError(connect.CodeFailedPrecondition, err)
	}
	resp := &nushiv1.ListSkillsResponse{PluginsError: list.PluginsError, BuiltInOff: list.BuiltInOff, BuiltInSetIn: list.BuiltInSetIn,
		NoSkills: list.NoSkills, NoSwitch: list.NoSwitch, ReadsShared: list.ReadsShared}
	for _, k := range list.Skills {
		sk := &nushiv1.Skill{Name: k.Name, Description: k.Description, Source: k.Source, Plugin: k.Plugin,
			Path: k.Path, State: k.State, SetIn: k.SetIn, Tokens: int32(min(k.Tokens, 1<<30)), Linked: k.Linked, Everywhere: k.Everywhere}
		for _, a := range k.Agents {
			sk.Agents = append(sk.Agents, &nushiv1.SkillAgent{Agent: a.Agent, State: a.State, SetIn: a.SetIn, Via: a.Via})
		}
		resp.Skills = append(resp.Skills, sk)
	}
	for _, p := range list.Plugins {
		resp.Plugins = append(resp.Plugins, &nushiv1.Plugin{Id: p.ID, Name: p.Name, Version: p.Version, Description: p.Description,
			Scope: p.Scope, Path: p.Path, Enabled: p.Enabled, Skills: int32(p.Skills), Commands: int32(p.Commands),
			Agents: int32(p.Agents), McpServers: int32(p.MCPServers), SwitchScope: s.skills.PluginScope(m.Agent, m.Folder, p)})
	}
	return connect.NewResponse(resp), nil
}

func (s *server) SetSkillOn(ctx context.Context, req *connect.Request[nushiv1.SetSkillOnRequest]) (*connect.Response[nushiv1.SetSkillOnResponse], error) {
	m := req.Msg
	return changed(s.skills.SetSkillOn(ctx, m.Agent, m.Folder, m.Source, m.Name, m.On), &nushiv1.SetSkillOnResponse{})
}

func (s *server) SetPluginOn(ctx context.Context, req *connect.Request[nushiv1.SetPluginOnRequest]) (*connect.Response[nushiv1.SetPluginOnResponse], error) {
	m := req.Msg
	return changed(s.skills.SetPluginOn(ctx, m.Agent, m.Folder, m.Id, m.On), &nushiv1.SetPluginOnResponse{})
}

func (s *server) UninstallPlugin(ctx context.Context, req *connect.Request[nushiv1.UninstallPluginRequest]) (*connect.Response[nushiv1.UninstallPluginResponse], error) {
	m := req.Msg
	return changed(s.skills.Uninstall(ctx, m.Agent, m.Folder, m.Id), &nushiv1.UninstallPluginResponse{})
}

func (s *server) TrashSkill(ctx context.Context, req *connect.Request[nushiv1.TrashSkillRequest]) (*connect.Response[nushiv1.TrashSkillResponse], error) {
	m := req.Msg
	return changed(s.skills.Trash(ctx, m.Agent, m.Folder, m.Path), &nushiv1.TrashSkillResponse{})
}

func (s *server) LinkSkill(ctx context.Context, req *connect.Request[nushiv1.LinkSkillRequest]) (*connect.Response[nushiv1.LinkSkillResponse], error) {
	m := req.Msg
	return changed(s.skills.Link(ctx, m.Agent, m.Folder, m.Path), &nushiv1.LinkSkillResponse{})
}
