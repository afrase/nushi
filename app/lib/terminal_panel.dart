import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'changes_span.dart';
import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart' show GetDiffRequest;
import 'panes.dart';
import 'settings.dart';
import 'terminal_screen.dart';
import 'terminal_tabs.dart';
import 'terminals.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// ⌃`: shows or hides the terminal panel.
const toggleTerminalKey = SingleActivator(
  LogicalKeyboardKey.backquote,
  control: true,
);

/// Shows or hides a chat's terminal panel.
void toggleTerminal(String chatId) {
  final open = terminalChats.value;
  terminalChats.value = open.contains(chatId)
      ? ({...open}..remove(chatId))
      : {...open, chatId};
}

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
    required this.onChanges,
    required this.child,
  });

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onChanges; // shows the Changes view
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

  // A file the Changes view lists (in Commits: what's uncommitted) shows
  // there.
  Future<bool> _showChange(String path) async {
    final chat = widget.chat;
    if (!path.startsWith('${chat.folder}/')) return false;
    final rel = path.substring(chat.folder.length + 1);
    final span = await ChangeSpan.of(widget.daemon, chat);
    final branch = span.scope == Scope.branch;
    final diff = await widget.daemon.client.getDiff(
      GetDiffRequest(folder: chat.folder, base: branch ? span.base : null),
    );
    if (!mounted || !diff.files.any((f) => f.path == rel)) return false;
    if (span.scope == Scope.commits) chat.scope = Scope.uncommitted.name;
    chat.showFile(rel);
    widget.onChanges();
    return true;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {toggleTerminalKey: _toggle},
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
                    showChange: _showChange,
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
    required this.showChange,
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
