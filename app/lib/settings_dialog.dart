import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

import 'agents_page.dart';
import 'bundled_daemon.dart';
import 'gen/nushi/v1/nushi.connect.client.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'login_item.dart';
import 'menu.dart';
import 'remote.dart';
import 'settings.dart';
import 'theme/theme.dart';
import 'widgets.dart';

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
/// data folder). Agents ([agents] opens on it): the agents found, and
/// their adapters.
Future<void> showSettings(
  BuildContext context,
  NushiServiceClient client, {
  bool agents = false,
}) => showDialog(context: context, builder: (_) => _Settings(client, agents));

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
  const _Settings(this.client, this.agents);

  final NushiServiceClient client;
  final bool agents;

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final _families = _monospaced();
  int? _sleep; // minutes, once the daemon said
  late bool _agents = widget.agents; // the page shown

  @override
  void initState() {
    super.initState();
    widget.client
        .getSettings(GetSettingsRequest())
        .then(
          (r) => mounted
              ? setState(() => _sleep = r.settings.sleepAfterMinutes)
              : null,
          onError: (_) {}, // the row stays out
        );
  }

  Future<void> _setSleep(int minutes) async {
    await widget.client.setSettings(
      SetSettingsRequest(settings: Settings(sleepAfterMinutes: minutes)),
    );
    if (mounted) setState(() => _sleep = minutes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
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
          if (_sleep case final sleep?) ...[
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
                      onPick: () => tryOrShow(context, () => _setSleep(key)),
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
            value: _agents,
            segments: const [(false, 'General'), (true, 'Agents')],
            onChanged: (v) => setState(() => _agents = v),
          ),
          const SizedBox(height: 12),
          _agents ? AgentsPage(widget.client) : general,
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
