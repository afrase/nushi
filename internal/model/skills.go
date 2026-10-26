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
}

// Skill is one skill, as its files give it.
type Skill struct {
	// Name is the skill's name as the agent lists it (a plugin's
	// "<plugin>:<skill>").
	Name string
	// Description is its front matter's (else its first line): text of
	// whoever wrote the skill, a third party's for a plugin's.
	Description string
	// Source is "user", "project" or "plugin"; Plugin is a plugin's id.
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
