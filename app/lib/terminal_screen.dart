import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' as pb;
import 'package:nushi/settings.dart';
import 'package:nushi/settings_general.dart';
import 'package:nushi/terminal_find.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/terminal_tabs.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:xterm2/xterm.dart';

/// One terminal's screen, and its exit with Restart once its shell ended.
class TerminalScreen extends StatelessWidget {
  const new({
    required this.info,
    required this.list,
    required this.terms,
    required this.onHide,
    required this.showChange,
    super.key,
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
      // The app's actions' keys (⌘N, ⌘,, ⌃⌘1–3…) and ⌘⇧P, the palette,
      // passed on; ⌘K clears here, as in Terminal, ⌘F finds here and ⌘W
      // closes this terminal, not a preview tab.
      for (final MapEntry(:key, :value) in actKeys.entries)
        if (!identical(key, findKey) && !identical(key, closeTabKey))
          key: value,
      paletteKeyToo: const OpenPaletteIntent(),
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
      // ⌥⌘1–9 a terminal; ⌘1–9, ⌘[ and ⌘] switch chats, ⌃Tab and ⌃⇧Tab
      // the chat's tabs, as elsewhere.
      for (var i = 0; i < 9 && i < list.length; i++)
        SingleActivator(LogicalKeyboardKey(0x31 + i), meta: true, alt: true):
            VoidCallbackIntent(() => terms.show(info.chatId, list[i].id)),
      ...chatKeys,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
            listenable: Listenable.merge([s, terminalFont, terminalFontSize]),
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
                  textStyle: terminalStyle(),
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
                  cursorType: TerminalCursorType.verticalBar,
                  cursorBlink: true,
                  keyboardAppearance: t.brightness,
                  shortcuts: _keys(context, s),
                  readOnly: info.exited,
                  // ⌘-click opens one thing: an OSC 8 link's real
                  // target, else the URL or file under the pointer.
                  onTapUp: (_, at) {
                    if (HardwareKeyboard.instance.isMetaPressed) {
                      unawaited(
                        openLink(
                          clickTarget(s.terminal, at),
                          info.folder,
                          showChange,
                        ),
                      );
                    }
                  },
                  onHover: (_, at) =>
                      s.hoveredLink.value = s.terminal.hyperlinkAt(at),
                  onExit: (_) => s.hoveredLink.value = null,
                ),
                // A link's text can say anything: its target shows here.
                ValueListenableBuilder(
                  valueListenable: s.hoveredLink,
                  builder: (context, link, _) => link == null
                      ? const SizedBox.shrink()
                      : Positioned(
                          left: 6,
                          bottom: 4,
                          right: 40,
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: box(
                                  t.borderStrong,
                                  fill: t.raised,
                                  radius: NushiTheme.control,
                                ),
                                child: Text(
                                  link,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.code(t.textSecondary, size: 11),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                ValueListenableBuilder(
                  valueListenable: s.finding,
                  builder: (context, finding, _) => finding
                      ? Positioned(
                          top: 6,
                          right: 14,
                          child: TerminalFindBar(session: s),
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
