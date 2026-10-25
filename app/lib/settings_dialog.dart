import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/agents_page.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_settings.dart';
import 'package:nushi/login_item.dart';
import 'package:nushi/logs_section.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:xterm2/xterm.dart';

/// The terminal's text: the picked font, then the bundled Nerd Font
/// symbols, so file and prompt icons show whatever font is picked.
TerminalStyle terminalStyle() => TerminalStyle(
  fontFamily: terminalFont.value ?? NushiTheme.codeFont,
  fontFamilyFallback: const ['Symbols Nerd Font Mono', NushiTheme.codeFont],
  fontSize: terminalFontSize.value,
  height: 1.25,
);

const _sizes = [10.0, 11.0, 12.0, 12.5, 13.0, 14.0, 15.0, 16.0, 18.0, 20.0];

/// The installed monospaced families (from the app's Swift side), but the
/// bundled one's name.
Future<List<String>> _monospaced() async {
  final all = await const MethodChannel('nushi/fonts')
      .invokeListMethod<String>('monospaced');
  return [...?all?.where((f) => f != NushiTheme.codeFont)];
}

const settingsKey = SingleActivator(LogicalKeyboardKey.comma, meta: true);

/// The app's settings (⌘,), on two pages. General: the terminal's font and
/// size, when idle chats sleep, remote access (both the daemon's), and
/// whether the daemon starts at login (the packaged app's, for the usual
/// data folder). Agents ([agents] opens on it, or [agent], whose row it
/// marks): the agents found, and their adapters. Jira ([jira]): the sites
/// and their tokens.
Future<void> showSettings(
  BuildContext context,
  NushiServiceClient client, {
  bool agents = false,
  String? agent,
  bool jira = false,
}) => showDialog(
  context: context,
  builder: (_) => _Settings(
    client,
    page: jira
        ? _Page.jira
        : agents || agent != null
        ? _Page.agents
        : _Page.general,
    agent: agent,
  ),
);

enum _Page { general, agents, jira }

/// The choices for when idle chats sleep, in minutes; 0: never.
const _sleepAfter = {
  0: 'Never',
  15: '15 minutes',
  30: '30 minutes',
  60: '1 hour',
  120: '2 hours',
};

String _sleepLabel(int m) => _sleepAfter[m] ?? '$m minute${m == 1 ? '' : 's'}';

class _Settings extends StatefulWidget {
  const new(this.client, {required this.page, this.agent});

  final NushiServiceClient client;
  final _Page page;
  final String? agent; // the agent whose row Agents marks

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final Future<List<String>> _families = _monospaced();
  Settings? _set; // the daemon's, once it said
  late _Page _page = widget.page; // the page shown

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.client
          .getSettings(GetSettingsRequest())
          .then(
            (r) => mounted ? setState(() => _set = r.settings) : null,
            onError: (_) {}, // the row stays out
          ),
    );
  }

  /// Sets the daemon's settings, both: [change] applied to them.
  Future<void> _change(void Function(Settings) change) async {
    final set = _set!.deepCopy();
    change(set);
    await widget.client.setSettings(SetSettingsRequest(settings: set));
    if (mounted) setState(() => _set = set);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Widget row(String label, Widget control) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: theme.ui(t.textSecondary)),
          ),
          control,
        ],
      ),
    );
    final value = theme.ui(t.text);
    final general = ListenableBuilder(
      listenable: Listenable.merge([terminalFont, terminalFontSize]),
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Terminal', style: theme.ui(t.text, weight: FontWeight.w600)),
          row(
            'Font',
            FutureBuilder(
              future: _families,
              builder: (context, families) => Menu(
                entries: [
                  MenuEntry(
                    NushiTheme.codeFont,
                    detail: 'bundled',
                    checked: terminalFont.value == null,
                    onPick: () => terminalFont.value = null,
                  ),
                  MenuEntry.divider,
                  for (final f in families.data ?? const <String>[])
                    MenuEntry(
                      f,
                      checked: terminalFont.value == f,
                      onPick: () => terminalFont.value = f,
                    ),
                ],
                child: Text(
                  terminalFont.value ?? NushiTheme.codeFont,
                  style: value,
                ),
              ),
            ),
          ),
          row(
            'Size',
            Menu(
              entries: [
                for (final s in _sizes)
                  MenuEntry(
                    '$s'.replaceAll('.0', ''),
                    checked: terminalFontSize.value == s,
                    onPick: () => terminalFontSize.value = s,
                  ),
              ],
              child: Text(
                '${terminalFontSize.value}'.replaceAll('.0', ''),
                style: value,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: box(t.borderSubtle, fill: t.base),
            child: Text(
              // Nerd Font icons: folder, Go, git branch, Apple.
              '~/nushi \u{e0a0} main\n\u{f07b} app  \u{e627} main.go  '
              '\u{f179} 0O1lI{}',
              style: terminalStyle().toTextStyle(color: t.text),
            ),
          ),
          if (_set?.sleepAfterMinutes case final sleep?) ...[
            const SizedBox(height: 16),
            Text('Chats', style: theme.ui(t.text, weight: FontWeight.w600)),
            row(
              'Sleep idle',
              Menu(
                entries: [
                  for (final MapEntry(:key, :value) in {
                    ..._sleepAfter,
                    sleep: _sleepLabel(sleep),
                  }.entries)
                    MenuEntry(
                      value,
                      checked: key == sleep,
                      onPick: () => tryOrShow(
                        context,
                        () => _change((s) => s.sleepAfterMinutes = key),
                      ),
                    ),
                ],
                child: Text(
                  sleep == 0 ? 'Never' : 'After ${_sleepLabel(sleep)}',
                  style: value,
                ),
              ),
            ),
          ],
          // The launch agent starts the usual data folder's daemon.
          if (bundledDaemon != null &&
              Platform.environment['NUSHI_DATA'] == null)
            const StartAtLogin(),
          RemoteSection(widget.client),
          LogsSection(
            debug: _set?.debugLog,
            onDebug: (on) =>
                tryOrShow(context, () => _change((s) => s.debugLog = on)),
          ),
        ],
      ),
    );
    return nushiDialog(
      'Settings',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Segmented(
            value: _page,
            segments: const [
              (_Page.general, 'General'),
              (_Page.agents, 'Agents'),
              (_Page.jira, 'Jira'),
            ],
            onChanged: (v) => setState(() => _page = v),
          ),
          const SizedBox(height: 12),
          // A short window scrolls the page.
          Flexible(
            child: switch (_page) {
              _Page.agents => AgentsPage(widget.client, marked: widget.agent),
              _Page.jira => JiraPage(widget.client),
              _Page.general => SingleChildScrollView(child: general),
            },
          ),
        ],
      ),
      [
        Button(
          label: 'Done',
          kind: ButtonKind.primary,
          autofocus: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
