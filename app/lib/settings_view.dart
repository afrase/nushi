import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/agents_page.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_settings.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/history_section.dart';
import 'package:nushi/jira_settings.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/logs_section.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/settings_appearance.dart';
import 'package:nushi/settings_general.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_shortcuts.dart';
import 'package:nushi/settings_terminal.dart';
import 'package:nushi/skills.dart';
import 'package:nushi/usage_page.dart';
import 'package:nushi/widgets.dart';

const settingsKey = Cmd(LogicalKeyboardKey.comma, id: 'settings');

/// Settings, open over the window (ADR 0087; ⌘,, Esc or Close shut it): a
/// nav of sections and the picked one's page. The daemon's settings are
/// asked for each time it opens ([DaemonSettings]), for the pages that
/// show them.
class SettingsView extends StatefulWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final DaemonSettings _settings;

  /// The integrations with an account that works, for the nav's dots: as
  /// known when Settings opens, then as their pages say.
  final Set<SettingsSection> _connected = {};

  Daemon get daemon => widget.daemon;

  /// Marks [s] connected or not, as its page or a listing found it.
  void _connect(SettingsSection s, {required bool on}) {
    if (!mounted || _connected.contains(s) == on) return;
    setState(() => on ? _connected.add(s) : _connected.remove(s));
  }

  /// The integrations already known to work this launch, without asking
  /// anything: a GitHub listing that found a host signed in, a Jira check
  /// that said who. Each page then marks its own as it finds it.
  void _knownConnected() {
    if (githubSignedInKnown) _connected.add(.github);
    if (jiraConnectedKnown) _connected.add(.jira);
  }

  @override
  void initState() {
    super.initState();
    _settings = DaemonSettings(daemon);
    _knownConnected();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  /// The folder MCP servers and Skills show when none was picked.
  String get _folder =>
      daemon.selected?.folder ?? Platform.environment['HOME'] ?? '/';

  Widget _page(SettingsSection s) => switch (s) {
    SettingsSection.general => GeneralSection(
      daemon: daemon,
      settings: _settings,
    ),
    SettingsSection.appearance => const AppearanceSection(),
    SettingsSection.terminal => const TerminalSection(),
    SettingsSection.shortcuts => const ShortcutsSection(),
    SettingsSection.history => HistorySection(
      daemon: daemon,
      settings: _settings,
    ),
    SettingsSection.usage => UsageSection(daemon: daemon),
    SettingsSection.remote => SettingsPage(
      title: s.title,
      children: [RemoteSection(daemon.client)],
    ),
    SettingsSection.agents => SettingsPage(
      title: s.title,
      children: [
        AgentsPage(
          daemon.client,
          marked: daemon.settingsOpen?.agent,
          settings: _settings,
        ),
      ],
    ),
    SettingsSection.mcp => McpView(
      daemon: daemon,
      folder: daemon.mcpFolder ?? _folder,
    ),
    SettingsSection.skills => SkillsView(
      daemon: daemon,
      folder: daemon.skillsFolder ?? _folder,
    ),
    SettingsSection.jira => SettingsPage(
      title: s.title,
      children: [
        JiraPage(daemon, onSites: (s) => _connect(.jira, on: jiraConnected(s))),
      ],
    ),
    SettingsSection.github => SettingsPage(
      title: s.title,
      children: [
        GitHubPage(
          daemon,
          onHosts: (h) => _connect(.github, on: githubConnected(h)),
        ),
      ],
    ),
    SettingsSection.logs => LogsSection(daemon: daemon, settings: _settings),
  };

  @override
  Widget build(BuildContext context) {
    final section = daemon.settingsOpen?.section ?? daemon.lastSettings;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsNav(
          section: section,
          connected: _connected,
          onPick: (s) => daemon.openSettings(section: s),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: KeyedSubtree(
                  key: ValueKey(section),
                  child: _page(section),
                ),
              ),
              // One title: Close sits in the page's corner, not on a bar of
              // its own over the page's title.
              Positioned(
                top: SettingsPage.closeInset,
                right: SettingsPage.closeInset,
                child: IconTap(
                  Icons.close,
                  tooltip: withKey('Close', 'Esc'),
                  onTap: daemon.closeSettings,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
