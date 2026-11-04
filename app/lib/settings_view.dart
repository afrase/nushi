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
import 'package:nushi/logs_section.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/settings_appearance.dart';
import 'package:nushi/settings_general.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_terminal.dart';
import 'package:nushi/skills.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

const settingsKey = SingleActivator(LogicalKeyboardKey.comma, meta: true);

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

  Daemon get daemon => widget.daemon;

  @override
  void initState() {
    super.initState();
    // Esc reaches the view from wherever the focus was.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focus.hasFocus) _focus.requestFocus();
    });
    _ask();
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
    SettingsSection.history => HistorySection(
      daemon: daemon,
      settings: _set,
      onChange: _change,
    ),
    SettingsSection.remote => SettingsPage(
      title: s.title,
      children: [RemoteSection(daemon.client)],
    ),
    SettingsSection.agents => SettingsPage(
      title: s.title,
      children: [AgentsPage(daemon.client, marked: daemon.settingsOpen?.agent)],
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
      children: [JiraPage(daemon)],
    ),
    SettingsSection.github => SettingsPage(
      title: s.title,
      children: [GitHubPage(daemon)],
    ),
    SettingsSection.logs => LogsSection(
      daemon: daemon,
      debug: _set?.debugLog,
      onDebug: (on) =>
          tryOrShow(context, () => _change((s) => s.debugLog = on)),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
            // The modal's title bar: no sidebar button or window drag, as
            // a view's header at the window's top has (ADR 0087).
            Container(
              height: PaneHeader.height,
              padding: const EdgeInsets.only(left: 16, right: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.borderSubtle)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Settings',
                      style: theme.ui(t.text, weight: FontWeight.w600),
                    ),
                  ),
                  IconTap(
                    Icons.close,
                    tooltip: 'Close (esc)',
                    onTap: daemon.closeSettings,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsNav(
                    section: section,
                    onPick: (s) => daemon.openSettings(section: s),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey(section),
                      child: _page(section),
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
