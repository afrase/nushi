import 'package:flutter/material.dart';

import 'package:nushi/menu.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_fonts.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/terminal_find.dart' show terminalStyle;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What Settings › Terminal shows in the picked font: a prompt with a
/// folder and a branch, `ls` with file-type icons (folder, Go, Dart,
/// Markdown) and a test's output, its icons drawn as the terminal's.
const terminalPreview =
    '\u{f07b} ~/nushi  \u{f418} main \$ ls\n'
    '\u{e5ff} cmd  \u{e65e} main.go  \u{e64c} l10n.dart  \u{f48a} NOTES.md\n'
    '\u{f07b} ~/nushi  \u{f418} main \$ go test ./app\n'
    'ok  nushi/app  0.42s';

const _sizes = [10.0, 11.0, 12.0, 12.5, 13.0, 14.0, 15.0, 16.0, 18.0, 20.0];

/// Settings › Terminal: the font, its size, and a preview.
class TerminalSection extends StatefulWidget {
  const new({super.key});

  @override
  State<TerminalSection> createState() => _TerminalSectionState();
}

class _TerminalSectionState extends State<TerminalSection> {
  final Future<List<String>> _families = installedFamilies(
    native.fonts.monospaced,
    bundled: NushiTheme.codeFont,
  );

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
                control: FontField(
                  picked: terminalFont,
                  bundled: NushiTheme.codeFont,
                  families: _families,
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
                // The terminal's style, its fallback too: ? boxes here are
                // the terminal's (docs/history/decisions-2026-10.md,
                // [controls]).
                child: Text(
                  terminalPreview,
                  key: const ValueKey('terminal-preview'),
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
