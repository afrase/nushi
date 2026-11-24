import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show GetDiffRequest;
import 'package:nushi/keys.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/terminal_screen.dart';
import 'package:nushi/terminal_tabs.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// ⌃`: shows or hides the terminal panel.
const toggleTerminalKey = Cmd(
  LogicalKeyboardKey.backquote,
  command: false,
  ctrl: true,
  id: 'terminal',
);

/// Shows or hides a chat's terminal panel.
void toggleTerminal(String chatId) => terminalChats.toggle(chatId);

/// Opens a terminal for [chat] in [folder] and shows its panel.
Future<void> openTerminalIn(
  Daemon daemon,
  ChatState chat,
  String folder,
) async {
  await daemon.terminals.open(chat.id, folder: folder);
  if (!terminalChats.value.contains(chat.id)) toggleTerminal(chat.id);
}

/// The header's button for the terminal panel.
class TerminalButton extends StatelessWidget {
  const new({required this.chat, required this.daemon, super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: terminalChats,
    builder: (context, open, _) {
      final on = open.contains(chat.id);
      return IconTap.line(
        LineIcon.terminal,
        tooltip: chat.archived
            ? 'An archived chat has no terminals'
            : on
            ? withKey('Hide terminal', keyLabel(toggleTerminalKey))
            : withKey('Show terminal', keyLabel(toggleTerminalKey)),
        padding: IconTap.header,
        lit: on,
        onTap: !chat.archived ? () => toggleTerminal(chat.id) : null,
      );
    },
  );
}

/// ⌃` for a chat's area: [onToggle] shows or hides the terminal panel.
/// [focus] is a node here that takes no Tab: what keeps the keys working
/// when what had the focus goes (the panel hidden, the details rail tucked
/// away; ADR 0123).
class TerminalKeys extends StatelessWidget {
  const new({
    required this.focus,
    required this.onToggle,
    required this.child,
    super.key,
  });

  final FocusNode focus;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {toggleTerminalKey: onToggle},
    child: Focus(focusNode: focus, child: child),
  );
}

/// Shows or hides [chat]'s terminal panel, none for an archived chat;
/// hiding it takes the focus out of the panel, so [keep] takes it for ⌃`.
void toggleTerminalOf(ChatState chat, FocusNode keep) {
  if (chat.archived) return;
  if (terminalChats.value.contains(chat.id)) keep.requestFocus();
  toggleTerminal(chat.id);
}

/// A chat's terminal panel, under its view while open, its height a
/// draggable edge; it slides up and down as it shows and hides.
class TerminalFoot extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onChanges,
    required this.onHide,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onChanges; // shows the Changes view
  final VoidCallback onHide;

  @override
  State<TerminalFoot> createState() => _TerminalFootState();
}

class _TerminalFootState extends State<TerminalFoot> {
  // A file the Changes view lists (in Commits: what's uncommitted) shows
  // there.
  Future<bool> _showChange(String path) async {
    final chat = widget.chat;
    final rel = insideOf(chat.folder, path);
    if (rel == null) return false;
    final span = await ChangeSpan.of(widget.daemon, chat);
    final diff = await widget.daemon.client.getDiff(
      span.scope == Scope.commits
          ? GetDiffRequest(folder: chat.folder)
          : span.diff(),
    );
    if (!mounted || !diff.files.any((f) => f.path == rel)) return false;
    if (span.scope == Scope.commits) chat.scope = Scope.uncommitted.name;
    chat.showFile(rel);
    widget.onChanges();
    return true;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: terminalChats,
    // As high as it's let be, less room for the view over it.
    builder: (context, open, _) => LayoutBuilder(
      // It slides up as it shows and down as it hides, laid out at its own
      // height throughout: its terminal's size (the PTY's) changes once,
      // not every frame. The chat above gets shorter as it rises, which
      // costs only its viewport.
      builder: (context, box) => BarSlide(
        down: false,
        fade: false,
        enter: Motion.enter,
        child: open.contains(widget.chat.id) && !widget.chat.archived
            ? Resizable(
                name: 'terminal',
                initial: 260,
                min: 100,
                max: box.maxHeight - 160,
                top: true,
                child: TerminalPanel(
                  chatId: widget.chat.id,
                  terms: widget.daemon.terminals,
                  onHide: widget.onHide,
                  showChange: _showChange,
                ),
              )
            : null,
      ),
    ),
  );
}

/// The panel: a tab per terminal over the one shown.
class TerminalPanel extends StatefulWidget {
  const new({
    required this.chatId,
    required this.terms,
    required this.onHide,
    required this.showChange,
    super.key,
  });

  final String chatId;

  /// Shows a file (an absolute path) in the Changes view if it's changed,
  /// and says whether it did.
  final Future<bool> Function(String path) showChange;
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

  Future<void>? _starting; // one at a time: two would open two shells

  // Opening the panel on a chat without terminals opens one ([open]).
  Future<void> _start({bool open = true}) =>
      _starting ??= _run(open).whenComplete(() => _starting = null);

  Future<void> _run(bool open) async {
    try {
      if (widget.terms.of(_chat) == null) await widget.terms.load(_chat);
      if (open && mounted && widget.terms.of(_chat)!.isEmpty) {
        await widget.terms.open(_chat);
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _changed() {
    final list = widget.terms.of(_chat);
    if (list == null) {
      // Reconnected: list them again, opening none (a restarted daemon
      // has none; the panel then hides, as when the last one closes).
      unawaited(_start(open: false));
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
        // The panel is built only while open: its tab is seen.
        if (shown != null) widget.terms.looked.add(shown.id);
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
                    : TerminalScreen(
                        key: ValueKey(shown.id),
                        info: shown,
                        list: list,
                        terms: widget.terms,
                        onHide: widget.onHide,
                        showChange: widget.showChange,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
