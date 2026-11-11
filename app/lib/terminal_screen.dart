import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' as pb;
import 'package:nushi/keys.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_find.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/terminal_tabs.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/widgets.dart';
import 'package:xterm2/xterm.dart';

// A terminal's own keys: ⌘ and a letter, as Terminal has them; on Linux
// Ctrl+Shift and the letter, as GNOME Terminal has them, since Ctrl and a
// letter is the shell's (ADR 0104).

/// Copies the terminal's selection.
const terminalCopyKey = Cmd(
  LogicalKeyboardKey.keyC,
  linux: SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true),
);

/// Pastes into the terminal.
const terminalPasteKey = Cmd(
  LogicalKeyboardKey.keyV,
  linux: SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true),
);

/// Clears the terminal's screen and scrollback.
const terminalClearKey = Cmd(
  LogicalKeyboardKey.keyK,
  linux: SingleActivator(LogicalKeyboardKey.keyK, control: true, shift: true),
);

/// Opens another terminal for the chat.
const newTerminalKey = Cmd(
  LogicalKeyboardKey.keyT,
  linux: SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true),
);

/// Closes the terminal.
const closeTerminalKey = Cmd(
  LogicalKeyboardKey.keyW,
  linux: SingleActivator(LogicalKeyboardKey.keyW, control: true, shift: true),
);

/// Finds in the terminal.
const terminalFindKey = Cmd(
  LogicalKeyboardKey.keyF,
  linux: SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true),
);

/// Ctrl+C, the shell's interrupt.
const _interruptKey = SingleActivator(LogicalKeyboardKey.keyC, control: true);

/// Where the command key is Control, Ctrl+C interrupts with text selected
/// too, as in GNOME Terminal (ADR 0104): off the Mac xterm2 would copy the
/// selection instead, before its shortcuts, so the selection goes and the
/// key reaches the shell. Ctrl+Shift+C copies.
KeyEventResult _interruptWithSelection(KeyEvent event, TermSession s) {
  if (commandKey == CommandKey.control &&
      _interruptKey.accepts(event, HardwareKeyboard.instance)) {
    s.controller.clearSelection();
  }
  return KeyEventResult.ignored;
}

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
  Map<ShortcutActivator, Intent> _keys(BuildContext context, TermSession s) => {
    // The app's keys a terminal passes on (`terminalPasses`: ⌘N, ⌘,,
    // ⌃⌘1–3…, ⌘⇧P, the palette, and ⌘1–9, ⌘[ and ⌘] that switch chats,
    // ⌃Tab and ⌃⇧Tab the chat's tabs); ⌘K clears here, as in Terminal, ⌘F
    // finds here and ⌘W closes this terminal, not a preview tab.
    for (final MapEntry(:key, :value) in {
      ...actKeys,
      paletteKeyToo: const OpenPaletteIntent(),
      ...chatKeys,
    }.entries)
      if (terminalPasses(key)) key: value,
    terminalCopyKey: CopySelectionTextIntent.copy,
    terminalPasteKey: const PasteTextIntent(SelectionChangedCause.keyboard),
    terminalClearKey: VoidCallbackIntent(s.terminal.clear),
    newTerminalKey: VoidCallbackIntent(
      () => tryOrShow(context, () => terms.open(info.chatId)),
    ),
    closeTerminalKey: VoidCallbackIntent(
      () => closeTerminal(context, terms, info),
    ),
    terminalFindKey: VoidCallbackIntent(s.find.open),
    toggleTerminalKey: VoidCallbackIntent(onHide),
    // ⌥⌘1–9 a terminal.
    for (var i = 0; i < 9 && i < list.length; i++)
      altDigitKey(i + 1): VoidCallbackIntent(
        () => terms.show(info.chatId, list[i].id),
      ),
  };

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
                  onKeyEvent: (_, event) => _interruptWithSelection(event, s),
                  readOnly: info.exited,
                  // ⌘-click (Ctrl-click on Linux) opens one thing: an OSC 8
                  // link's real target, else the URL or file under the
                  // pointer.
                  onTapUp: (_, at) {
                    if (cmdPressed()) {
                      unawaited(
                        openLink(
                          context,
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
                                  radius: NushiTheme.tag,
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
                ListenableBuilder(
                  listenable: s.find,
                  builder: (context, _) => s.find.query == null
                      ? const SizedBox.shrink()
                      : Positioned(
                          top: 6,
                          right: 14,
                          child: FindBar(s.find, hint: 'Find in the terminal'),
                        ),
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

/// The app's colors with the theme's ANSI palette ([Tokens.terminal]);
/// [cursor] in place of the text's (the background's hides it).
TerminalTheme terminalTheme(Tokens t, {Color? cursor}) {
  final a = t.terminal;
  return TerminalTheme(
    cursor: cursor ?? t.text,
    selection: t.accent.withValues(alpha: 0.3),
    foreground: t.text,
    background: t.base,
    black: a.black,
    red: a.red,
    green: a.green,
    yellow: a.yellow,
    blue: a.blue,
    magenta: a.magenta,
    cyan: a.cyan,
    white: a.white,
    brightBlack: a.brightBlack,
    brightRed: a.brightRed,
    brightGreen: a.brightGreen,
    brightYellow: a.brightYellow,
    brightBlue: a.brightBlue,
    brightMagenta: a.brightMagenta,
    brightCyan: a.brightCyan,
    brightWhite: a.brightWhite,
    searchHitBackground: t.needsSoft,
    searchHitBackgroundCurrent: t.needs,
    searchHitForeground: t.text,
  );
}
