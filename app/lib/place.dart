import 'package:flutter/foundation.dart' show immutable;

/// Settings' sections, in the order the nav lists them (their icons are
/// the nav's, `settings_nav.dart`).
enum SettingsSection {
  general('General'),
  terminal('Terminal'),
  history('Chat history'),
  remote('Remote access'),
  agents('Agents'),
  mcp('MCP servers'),
  skills('Skills'),
  jira('Jira'),
  github('GitHub'),
  logs('Logs & advanced');

  new(this.title);

  final String title;
}

/// What shows in the chat's place beside the sidebar (ADR 0053): the chat
/// itself, or a view that takes its place. One at a time, so the views
/// can't disagree; the trust card shows over whichever it is.
@immutable
sealed class Place {
  const new();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The selected chat, or what shows when none is.
final class ChatPlace extends Place {
  const new();
}

/// Settings at [section]; [agent] is the row Settings › Agents marks (a
/// chat that couldn't start it sent you there).
final class SettingsPlace extends Place {
  const new(this.section, {this.agent});

  final SettingsSection section;
  final String? agent;

  @override
  bool operator ==(Object other) =>
      other is SettingsPlace &&
      other.section == section &&
      other.agent == agent;

  @override
  int get hashCode => Object.hash(section, agent);
}

/// The Jira view (⌘J).
final class JiraPlace extends Place {
  const new();
}

/// The GitHub view (⌘G).
final class GitHubPlace extends Place {
  const new();
}
