package model

// Skills is what an agent's skills manager shows for a folder: its skills,
// its plugins, and whether the agent's own built-in skills are on.
type Skills struct {
	Skills  []Skill
	Plugins []Plugin
	// PluginsError says why the plugins couldn't be listed (their skills
	// are then missing too).
	PluginsError string
	// BuiltInOff says the agent's built-in skills are turned off;
	// BuiltInSetIn names a settings file that decides it other than the
	// one Nushi changes.
	BuiltInOff   bool
	BuiltInSetIn string
	// NoSkills says why the agent has no skills to show ("" when it has).
	NoSkills string
	// NoSwitch says why the agent's skills have no switch ("" when they
	// have one).
	NoSwitch string
	// ReadsShared says the agent reads the project's .agents/skills (or
	// will once the folder is trusted).
	ReadsShared bool
}

// Find is the listed skill of source and name, the first if several.
func (s Skills) Find(source, name string) (Skill, bool) {
	for _, sk := range s.Skills {
		if sk.Source == source && sk.Name == name {
			return sk, true
		}
	}
	return Skill{}, false
}

// Skill is one skill, as its files give it.
type Skill struct {
	// Name is the skill's name as the agent lists it (a plugin's
	// "<plugin>:<skill>").
	Name string
	// Description is its front matter's (else its first line): text of
	// whoever wrote the skill, a third party's for a plugin's.
	Description string
	// Source is "user", "project", "plugin", "system" (the agent's own,
	// installed with it) or "shared" (.agents/skills, which several agents
	// read); Plugin is a plugin's id.
	Source, Plugin string
	// Path is the skill's folder (SKILL.md is in it).
	Path string
	// State is "on", "name-only", "user-invocable-only" or "off"; SetIn
	// names a settings file that decides it other than the one Nushi
	// changes for the skill.
	State, SetIn string
	// Tokens is about what listing the skill costs every session's
	// context.
	Tokens int
	// Everywhere says a shared skill is in your own shared folder
	// (~/.agents/skills), not the project's.
	Everywhere bool
	// Linked is where Path points when the skill's folder is a symlink,
	// as the link says.
	Linked string
	// Agents are the agents that read a shared skill's folder, each with
	// the skill's state for it.
	Agents []SkillAgent
}

// SkillAgent is a shared skill as one agent has it.
type SkillAgent struct {
	// Agent is the agent's name ("codex").
	Agent string
	// State is "on", "off", or "untrusted": the agent loads it once the
	// folder is trusted. SetIn is as Skill's.
	State, SetIn string
	// Via is the agent's own skill folder that is a link to it (Claude's
	// .claude/skills/<name>), when that's how the agent loads it.
	Via string
}

// Plugin is one installed plugin, with what it brings.
type Plugin struct {
	// ID is "<name>@<marketplace>".
	ID, Name, Version, Description string
	// Scope is where it's installed: "user", "project" or "local".
	Scope string
	// Path is its folder.
	Path    string
	Enabled bool
	// What it brings, counted.
	Skills, Commands, Agents, MCPServers int
}
