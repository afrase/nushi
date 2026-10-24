import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

import 'menu.dart';
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

/// The app's settings (⌘,): the terminal's font and size.
Future<void> showSettings(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _Settings());

class _Settings extends StatefulWidget {
  const _Settings();

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final _families = _monospaced();

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
    return nushiDialog(
      'Settings',
      ListenableBuilder(
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
          ],
        ),
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
