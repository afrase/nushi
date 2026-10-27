import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/login_item.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:xterm2/xterm.dart';

/// Changes the daemon's settings: the function given applied to them.
typedef SettingsChange = Future<void> Function(void Function(Settings));

/// The choices for when idle chats sleep, in minutes; 0: never.
const _sleepAfter = {
  0: 'Never',
  15: '15 minutes',
  30: '30 minutes',
  60: '1 hour',
  120: '2 hours',
};

String _sleepLabel(int m) => _sleepAfter[m] ?? '$m minute${m == 1 ? '' : 's'}';

/// Settings › General: when idle chats sleep, and whether the daemon
/// starts at login (the packaged app's, for the usual data folder).
/// [settings] is the daemon's, null until it said.
class GeneralSection extends StatelessWidget {
  const new({required this.settings, required this.onChange, super.key});

  final Settings? settings;
  final SettingsChange onChange;

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'General',
    children: [
      if (settings?.sleepAfterMinutes case final sleep?)
        SettingsGroup(
          title: 'Chats',
          children: [
            SettingsRow(
              'Sleep idle chats',
              description:
                  "An idle chat's agent stops; the next message wakes it.",
              control: MenuField(
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
                        () => onChange((s) => s.sleepAfterMinutes = key),
                      ),
                    ),
                ],
                label: Text(
                  sleep == 0 ? 'Never' : 'After ${_sleepLabel(sleep)}',
                ),
              ),
            ),
          ],
        ),
      // The launch agent starts the usual data folder's daemon.
      if (bundledDaemon != null && Platform.environment['NUSHI_DATA'] == null)
        const StartAtLogin(),
    ],
  );
}

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

/// Settings › Terminal: the font, its size, and a preview.
class TerminalSection extends StatefulWidget {
  const new({super.key});

  @override
  State<TerminalSection> createState() => _TerminalSectionState();
}

class _TerminalSectionState extends State<TerminalSection> {
  final Future<List<String>> _families = _monospaced();

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ListenableBuilder(
      listenable: Listenable.merge([terminalFont, terminalFontSize]),
      builder: (context, _) => SettingsPage(
        title: 'Terminal',
        children: [
          SettingsGroup(
            children: [
              SettingsRow(
                'Font',
                description: 'Nerd Font icons come from a bundled font.',
                control: FutureBuilder(
                  future: _families,
                  builder: (context, families) => MenuField(
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
                    label: Text(terminalFont.value ?? NushiTheme.codeFont),
                  ),
                ),
              ),
              SettingsRow(
                'Size',
                control: MenuField(
                  entries: [
                    for (final s in _sizes)
                      MenuEntry(
                        '$s'.replaceAll('.0', ''),
                        checked: terminalFontSize.value == s,
                        onPick: () => terminalFontSize.value = s,
                      ),
                  ],
                  label: Text('${terminalFontSize.value}'.replaceAll('.0', '')),
                ),
              ),
            ],
          ),
          SettingsGroup(
            title: 'Preview',
            children: [
              Container(
                color: t.base,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  // Nerd Font icons: folder, Go, git branch, Apple.
                  '~/nushi \u{e0a0} main\n\u{f07b} app  \u{e627} main.go  '
                  '\u{f179} 0O1lI{}',
                  style: terminalStyle().toTextStyle(color: t.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
