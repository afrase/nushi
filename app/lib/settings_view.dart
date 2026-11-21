import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/agents_page.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
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
import 'package:nushi/settings_terminal.dart';
import 'package:nushi/skills.dart';
import 'package:nushi/usage_page.dart';
import 'package:nushi/widgets.dart';

const settingsKey = Cmd(LogicalKeyboardKey.comma, id: 'settings');

/// Settings, open over the window (ADR 0087; ⌘,, Esc or Close shut it): a
/// nav of sections and the picked one's page. The daemon's settings are
/// asked for once it opens.
class SettingsView extends StatefulWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _focus = FocusNode(debugLabel: 'settings');
  Settings? _set; // the daemon's, once it said
  bool _asking = false;

  // The settings asked for while the daemon was gone.
  late final _again = LoadAgain(daemon, () {
    if (mounted) _ask();
  });

  /// The changes being made, one after another: each sends every setting
  /// (SetSettings), so each starts from what the one before set.
  Future<void> _changes = Future.value();

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
    // Esc reaches the view from wherever the focus was.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focus.hasFocus) _focus.requestFocus();
    });
    _ask();
    _knownConnected();
  }

  @override
  void dispose() {
    _again.cancel();
    _focus.dispose();
    super.dispose();
  }

  /// Asks for the daemon's settings; the rows that need them stay out until
  /// it said.
  void _ask() {
    if (_set != null || _asking) return;
    _asking = true;
    unawaited(
      daemon.client
          .getSettings(GetSettingsRequest())
          .then(
            (r) => mounted ? setState(() => _set = r.settings) : null,
            onError: _again.failed, // asked again when the daemon is back
          )
          .whenComplete(() => _asking = false),
    );
  }

  /// Sets the daemon's settings: [change] applied to them, after the
  /// changes asked before it.
  Future<void> _change(void Function(Settings) change) {
    final done = _changes.then((_) async {
      final set = _set!.deepCopy();
      change(set);
      await daemon.client.setSettings(SetSettingsRequest(settings: set));
      _set = set;
      if (mounted) setState(() {});
    });
    _changes = done.then((_) {}, onError: (_) {}); // a failure is the asker's
    return done;
  }

  /// The folder MCP servers and Skills show when none was picked.
  String get _folder =>
      daemon.selected?.folder ?? Platform.environment['HOME'] ?? '/';

  Widget _page(SettingsSection s) => switch (s) {
    SettingsSection.general => GeneralSection(
      daemon: daemon,
      settings: _set,
      onChange: _change,
    ),
    SettingsSection.appearance => const AppearanceSection(),
    SettingsSection.terminal => const TerminalSection(),
    SettingsSection.shortcuts => SettingsPage(title: s.title),
    SettingsSection.history => HistorySection(
      daemon: daemon,
      settings: _set,
      onChange: _change,
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
          settings: _set,
          onChange: _change,
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
    SettingsSection.logs => LogsSection(
      daemon: daemon,
      debug: _set?.debugLog,
      onDebug: ({required on}) => _change((s) => s.debugLog = on),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final section = daemon.settingsOpen?.section ?? daemon.lastSettings;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): daemon.closeSettings,
      },
      child: Focus(
        focusNode: _focus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
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
                        // One title: Close sits in the page's corner, not
                        // on a bar of its own over the page's title.
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
