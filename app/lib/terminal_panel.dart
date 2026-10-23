import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart' as pb;
import 'panes.dart';
import 'settings.dart';
import 'terminal_tabs.dart';
import 'terminals.dart';
import 'theme/theme.dart';
import 'widgets.dart';

const _toggleKey = SingleActivator(LogicalKeyboardKey.backquote, control: true);

/// Shows or hides a chat's terminal panel.
void toggleTerminal(String chatId) {
  final open = terminalChats.value;
  terminalChats.value = open.contains(chatId)
      ? ({...open}..remove(chatId))
      : {...open, chatId};
}

/// The header's button for the terminal panel.
class TerminalButton extends StatelessWidget {
  const TerminalButton({super.key, required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: terminalChats,
    builder: (context, open, _) {
      final t = NushiTheme.of(context).t;
      final on = open.contains(chat.id);
      return IconTap(
        Icons.terminal,
        tooltip: !daemon.canTerminals
            ? 'Terminals need a newer daemon'
            : chat.archived
            ? 'An archived chat has no terminals'
            : on
            ? 'Hide terminal  ⌃`'
            : 'Show terminal  ⌃`',
        color: on ? t.text : t.textSecondary,
        onTap: daemon.canTerminals && !chat.archived
            ? () => toggleTerminal(chat.id)
            : null,
      );
    },
  );
}

/// A chat's view with its terminal panel under it while open, its height a
/// draggable edge. ⌃` shows or hides the panel.
class TerminalArea extends StatefulWidget {
  const TerminalArea({
    super.key,
    required this.chat,
    required this.daemon,
    required this.child,
  });

  final ChatState chat;
  final Daemon daemon;
  final Widget child;

  @override
  State<TerminalArea> createState() => _TerminalAreaState();
}

class _TerminalAreaState extends State<TerminalArea> {
  final _focus = FocusNode(skipTraversal: true);

  void _toggle() {
    if (!widget.daemon.canTerminals || widget.chat.archived) return;
    // Hiding takes the focus out of the panel; keep it here for ⌃`.
    if (terminalChats.value.contains(widget.chat.id)) _focus.requestFocus();
    toggleTerminal(widget.chat.id);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {_toggleKey: _toggle},
    child: Focus(
      focusNode: _focus,
      child: ValueListenableBuilder(
        valueListenable: terminalChats,
        builder: (context, open, _) => LayoutBuilder(
          builder: (context, box) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: widget.child),
              if (open.contains(widget.chat.id) &&
                  widget.daemon.canTerminals &&
                  !widget.chat.archived)
                Resizable(
                  name: 'terminal',
                  initial: 260,
                  min: 100,
                  max: box.maxHeight - 160,
                  top: true,
                  child: TerminalPanel(
                    chatId: widget.chat.id,
                    terms: widget.daemon.terminals,
                    onHide: _toggle,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The panel: a tab per terminal over the one shown.
class TerminalPanel extends StatefulWidget {
  const TerminalPanel({
    super.key,
    required this.chatId,
    required this.terms,
    required this.onHide,
  });

  final String chatId;
  final Terminals terms;
  final VoidCallback onHide;

  @override
  State<TerminalPanel> createState() => _PanelState();
}

class _PanelState extends State<TerminalPanel> {
  bool _hadSome = false; // closing the last tab hides the panel

  String get _chat => widget.chatId;

  @override
  void initState() {
    super.initState();
    widget.terms.addListener(_changed);
    unawaited(_start());
  }

  // Opening the panel on a chat without terminals opens one.
  Future<void> _start() async {
    try {
      if (widget.terms.of(_chat) == null) await widget.terms.load(_chat);
      if (mounted && widget.terms.of(_chat)!.isEmpty) {
        await widget.terms.open(_chat);
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _changed() {
    final list = widget.terms.of(_chat);
    if (list == null) {
      unawaited(_start()); // reconnected: list them again
      return;
    }
    if (list.isNotEmpty) {
      _hadSome = true;
    } else if (_hadSome) {
      _hadSome = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onHide());
    }
  }

  @override
  void dispose() {
    widget.terms.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ListenableBuilder(
      listenable: widget.terms,
      builder: (context, _) {
        final list = widget.terms.of(_chat) ?? [];
        final shown = list
            .where((x) => x.id == widget.terms.active[_chat])
            .firstOrNull;
        return ColoredBox(
          color: t.base,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TerminalTabs(
                chatId: _chat,
                terms: widget.terms,
                list: list,
                onHide: widget.onHide,
              ),
              Expanded(
                child: shown == null
                    ? const SizedBox.shrink()
                    : _Screen(
                        key: ValueKey(shown.id),
                        info: shown,
                        list: list,
                        terms: widget.terms,
                        onHide: widget.onHide,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One terminal's screen, and its exit with Restart once its shell ended.
class _Screen extends StatelessWidget {
  const _Screen({
    super.key,
    required this.info,
    required this.list,
    required this.terms,
    required this.onHide,
  });

  final pb.Terminal info;
  final List<pb.Terminal> list;
  final Terminals terms;
  final VoidCallback onHide;

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
      _toggleKey: VoidCallbackIntent(onHide),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => TerminalView(
              s.terminal,
              key: ObjectKey(s.terminal),
              controller: s.controller,
              focusNode: s.focus,
              autofocus: true,
              theme: terminalTheme(t),
              textStyle: const TerminalStyle(
                fontFamily: NushiTheme.codeFont,
                fontSize: 12.5,
                height: 1.25,
              ),
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
              cursorType: TerminalCursorType.verticalBar,
              cursorBlink: true,
              keyboardAppearance: t.brightness,
              shortcuts: _keys(context, s),
              readOnly: info.exited,
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
