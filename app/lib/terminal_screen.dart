import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

import 'gen/nushi/v1/nushi.pb.dart' as pb;
import 'terminal_find.dart';
import 'terminal_panel.dart';
import 'terminal_tabs.dart';
import 'terminals.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// One terminal's screen, and its exit with Restart once its shell ended.
class TerminalScreen extends StatelessWidget {
  const TerminalScreen({
    super.key,
    required this.info,
    required this.list,
    required this.terms,
    required this.onHide,
    required this.showChange,
  });

  final pb.Terminal info;
  final List<pb.Terminal> list;
  final Terminals terms;
  final VoidCallback onHide;
  final Future<bool> Function(String path) showChange;

  /// The keys the panel keeps for itself; the rest go to the shell.
  Map<ShortcutActivator, Intent> _keys(BuildContext context, TermSession s) {
    SingleActivator cmd(LogicalKeyboardKey key) =>
        SingleActivator(key, meta: true);
    return {
      cmd(LogicalKeyboardKey.keyC): CopySelectionTextIntent.copy,
      cmd(LogicalKeyboardKey.keyV): const PasteTextIntent(
        SelectionChangedCause.keyboard,
      ),
      cmd(LogicalKeyboardKey.keyK): VoidCallbackIntent(s.terminal.clear),
      cmd(LogicalKeyboardKey.keyT): VoidCallbackIntent(
        () => tryOrShow(context, () => terms.open(info.chatId)),
      ),
      cmd(LogicalKeyboardKey.keyW): VoidCallbackIntent(
        () => closeTerminal(context, terms, info),
      ),
      toggleTerminalKey: VoidCallbackIntent(onHide),
      cmd(LogicalKeyboardKey.keyF): VoidCallbackIntent(
        () => s.finding.value = true,
      ),
      for (var i = 0; i < 9 && i < list.length; i++)
        cmd(LogicalKeyboardKey(0x31 + i)): VoidCallbackIntent(
          () => terms.show(info.chatId, list[i].id),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final s = terms.session(info);
    if (terms.focusNext == info.id) {
      terms.focusNext = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => s.focus.requestFocus(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => Stack(
              children: [
                TerminalView(
                  s.terminal,
                  key: ObjectKey(s.terminal),
                  controller: s.controller,
                  scrollController: s.scroll,
                  focusNode: s.focus,
                  autofocus: true,
                  theme: terminalTheme(t),
                  textStyle: const TerminalStyle(
                    fontFamily: NushiTheme.codeFont,
                    fontSize: TermSession.fontSize,
                    height: TermSession.lineHeight,
                  ),
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
                  cursorType: TerminalCursorType.verticalBar,
                  cursorBlink: true,
                  keyboardAppearance: t.brightness,
                  shortcuts: _keys(context, s),
                  readOnly: info.exited,
                  // ⌘-click opens a URL or a file in the output.
                  onTapUp: (_, at) {
                    if (HardwareKeyboard.instance.isMetaPressed) {
                      openLink(wordAt(s.terminal, at), info.folder, showChange);
                    }
                  },
                  onHyperlinkTap: (uri) =>
                      openLink(uri, info.folder, showChange),
                ),
                ValueListenableBuilder(
                  valueListenable: s.finding,
                  builder: (context, finding, _) => finding
                      ? Positioned(
                          top: 6,
                          right: 14,
                          child: FindBar(session: s),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        if (info.exited)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    info.exitCode < 0
                        ? 'The shell was killed.'
                        : 'The shell exited with code ${info.exitCode}.',
                    style: theme.ui(t.textSecondary, size: 12),
                  ),
                ),
                Button(
                  label: 'Restart',
                  onPressed: () =>
                      tryOrShow(context, () => terms.restart(info.id)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The app's colors with VS Code's ANSI palettes, for one brightness.
TerminalTheme terminalTheme(Tokens t) {
  final dark = t.brightness == Brightness.dark;
  Color c(int light, int darkColor) => Color(dark ? darkColor : light);
  return TerminalTheme(
    cursor: t.text,
    selection: t.accent.withValues(alpha: 0.3),
    foreground: t.text,
    background: t.base,
    black: c(0xFF000000, 0xFF000000),
    red: c(0xFFCD3131, 0xFFCD3131),
    green: c(0xFF00BC00, 0xFF0DBC79),
    yellow: c(0xFF949800, 0xFFE5E510),
    blue: c(0xFF0451A5, 0xFF2472C8),
    magenta: c(0xFFBC05BC, 0xFFBC3FBC),
    cyan: c(0xFF0598BC, 0xFF11A8CD),
    white: c(0xFF555555, 0xFFE5E5E5),
    brightBlack: c(0xFF666666, 0xFF666666),
    brightRed: c(0xFFCD3131, 0xFFF14C4C),
    brightGreen: c(0xFF14CE14, 0xFF23D18B),
    brightYellow: c(0xFFB5BA00, 0xFFF5F543),
    brightBlue: c(0xFF0451A5, 0xFF3B8EEA),
    brightMagenta: c(0xFFBC05BC, 0xFFD670D6),
    brightCyan: c(0xFF0598BC, 0xFF29B8DB),
    brightWhite: c(0xFFA5A5A5, 0xFFE5E5E5),
    searchHitBackground: t.needsSoft,
    searchHitBackgroundCurrent: t.needs,
    searchHitForeground: t.text,
  );
}
