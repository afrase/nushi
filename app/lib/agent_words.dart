/// An agent's own names for what Nushi shows of it, where they differ by
/// agent: the command that manages its MCP servers, the one that manages
/// its plugins, and the setting that turns its built-in skills off. Wording
/// only, keyed by name as per-agent words may be (ADR 0077): nothing is
/// shown or offered by it. Null where Nushi doesn't know the agent's, and
/// the words then go without.
typedef AgentWords = ({
  String? mcpCommand,
  String? pluginCommand,
  String? builtInSetting,
});

/// [agent]'s own names, as [AgentWords] says.
AgentWords agentWords(String agent) => switch (agent) {
  'claude' => (
    mcpCommand: '/mcp',
    pluginCommand: '/plugin',
    builtInSetting: 'disableBundledSkills',
  ),
  _ => (mcpCommand: null, pluginCommand: null, builtInSetting: null),
};
