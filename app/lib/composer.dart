import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'chat_menu.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'images.dart';
import 'pickers.dart';
import 'theme/theme.dart';
import 'thinking.dart';
import 'composer_parts.dart';

/// Stops the chat's running turn.
Future<void> stopTurn(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async {
  if (chat.started == null) return;
  try {
    await daemon.cancelTurn(chat.id);
  } on Object catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// The prompt box: "+" on its left mentions a file or attaches images
/// (⌘V and dropping work too), and on its right a send button once there
/// is something to send, or a stop button while a turn runs. Attached
/// images show above the text. Under it, the agent's pickers. Enter sends,
/// Shift-Enter starts a line; `/` completes the agent's commands and `@`
/// the folder's files (sent as links); Up in an empty box brings back the
/// last prompt.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.chat,
    required this.daemon,
    required this.quote,
    this.attachments,
    this.hint = 'Type / for commands',
  });

  final ChatState chat;
  final Daemon daemon;

  /// Text to quote in the box (Reply), cursor after it; taken and cleared.
  final ValueNotifier<String?> quote;

  /// The images to send with the prompt; the box keeps its own if null.
  final Attachments? attachments;
  final String hint;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _mentions = <String>{}; // files picked with @
  List<String> _lastFiles = []; // the last prompt's, for Up
  List<String>? _files; // the folder's, fetched at the first @
  String _filesOf = ''; // the folder they are of
  List<Choice> _choices = [];
  int _picked = 0;
  (int, int)? _token; // where the text being completed starts and ends
  String _dismissed = ''; // the text Escape closed the choices for
  late final _images = widget.attachments ?? Attachments();

  @override
  void initState() {
    super.initState();
    _images.addListener(_imagesChanged);
    _text.addListener(_complete);
    widget.quote.addListener(_quote);
    _quote(); // one given before the box was built
  }

  void _imagesChanged() => setState(() {});

  /// The "+" menu: mention a file, or attach images.
  Future<void> _plus(BuildContext button) async {
    final picked = await plusMenu(button, images: widget.chat.canImages);
    if (!mounted) return;
    switch (picked) {
      case 'file':
        _mention();
      case 'image':
        await tryOrShow(context, _images.pick);
    }
  }

  @override
  void dispose() {
    _images.removeListener(_imagesChanged);
    if (widget.attachments == null) _images.dispose();
    widget.quote.removeListener(_quote);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _quote() {
    final q = widget.quote.value;
    if (q == null) return;
    widget.quote.value = null;
    final quoted = q.trim().split('\n').map((l) => '> $l').join('\n');
    final before = _text.text.trim().isEmpty
        ? ''
        : '${_text.text.trimRight()}\n\n';
    final text = '$before$quoted\n\n';
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.requestFocus();
  }

  void _complete() {
    final caret = _text.selection.baseOffset;
    final before = caret < 0 ? '' : _text.text.substring(0, caret);
    var choices = <Choice>[];
    _token = null;
    if (RegExp(r'^/(\S*)$').firstMatch(before) case final m?) {
      final names = {for (final c in widget.chat.commands) c.name: c};
      choices = [
        for (final n in _rank(names.keys, m[1]!))
          (label: '/$n', detail: names[n]!.description, insert: '/$n '),
      ];
      _token = (0, caret);
    } else if (RegExp(r'(^|\s)@(\S*)$').firstMatch(before) case final m?) {
      final folder = widget.chat.folder;
      final files = _filesOf == folder ? _files : null;
      if (files == null) {
        _files = const [];
        _filesOf = folder;
        widget.daemon.listFiles(folder).then((f) {
          _files = f;
          if (mounted) _complete();
        }, onError: (_) => _files = null);
      }
      choices = [
        for (final f in _rank(files ?? const [], m[2]!))
          (label: f, detail: '', insert: '@$f '),
      ];
      _token = (caret - m[2]!.length - 1, caret);
    }
    if (_text.text == _dismissed) choices = [];
    setState(() {
      _choices = choices.take(8).toList();
      _picked = 0;
    });
  }

  /// The names holding [q], those whose last part starts with it first,
  /// then the shortest.
  static List<String> _rank(Iterable<String> names, String q) {
    q = q.toLowerCase();
    final hits = [
      for (final n in names)
        if (n.toLowerCase().contains(q)) n,
    ];
    int score(String n) =>
        (n.split(RegExp('[/:]')).last.toLowerCase().startsWith(q) ? 0 : 1000) +
        n.length;
    hits.sort((a, b) => score(a) - score(b));
    return hits.take(8).toList();
  }

  /// Starts an @ mention at the cursor, which offers the folder's files.
  void _mention() {
    final sel = _text.selection;
    final at = sel.isValid ? sel.start : _text.text.length;
    final before = _text.text.substring(0, at);
    final insert =
        before.isEmpty || before.endsWith(' ') || before.endsWith('\n')
        ? '@'
        : ' @';
    _text.value = TextEditingValue(
      text: _text.text.replaceRange(at, sel.isValid ? sel.end : at, insert),
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
    _dismissed = '';
    _focus.requestFocus();
  }

  void _accept(Choice c) {
    final (start, end) = _token!;
    final text = _text.text.replaceRange(start, end, c.insert);
    if (c.insert.startsWith('@')) _mentions.add(c.label);
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + c.insert.length),
    );
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (_choices.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp) {
        final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
        setState(() => _picked = (_picked + step) % _choices.length);
        return KeyEventResult.handled;
      }
      if ((key == LogicalKeyboardKey.enter && !shift) ||
          key == LogicalKeyboardKey.tab) {
        _accept(_choices[_picked]);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _dismissed = _text.text;
        setState(() => _choices = []);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.enter && !shift) {
      _send();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV &&
        HardwareKeyboard.instance.isMetaPressed &&
        widget.chat.canImages) {
      tryOrShow(context, _images.paste); // text, if any, pastes as usual
    }
    if (key == LogicalKeyboardKey.arrowUp && _text.text.isEmpty) {
      final last = widget.chat.items.lastWhere(
        (it) => it.kind == ItemKind.ITEM_KIND_USER_MESSAGE,
        orElse: Item.new,
      );
      _mentions.addAll(_lastFiles);
      _text.value = TextEditingValue(
        text: last.text,
        selection: TextSelection.collapsed(offset: last.text.length),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    final images = _images.value;
    if (text.isEmpty && images.isEmpty || widget.chat.busy) return;
    final files = [
      for (final f in _mentions)
        if (text.contains('@$f')) f,
    ];
    _text.clear();
    _images.clear();
    _mentions.clear();
    _lastFiles = files;
    try {
      await widget.daemon.sendPrompt(widget.chat.id, text, files, images);
    } on Object catch (e) {
      _text.text = text;
      _images.value = images;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  /// The plan of the current turn (since the last prompt), if any.
  Item? get _plan {
    for (final it in widget.chat.items.reversed) {
      if (it.kind == ItemKind.ITEM_KIND_USER_MESSAGE) return null;
      if (it.kind == ItemKind.ITEM_KIND_PLAN) return it;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_plan case final plan? when chat.busy) PlanStatus(plan),
          if (chat.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(chat.error, style: theme.ui(t.crashed, size: 12)),
            ),
          if (_choices.isNotEmpty)
            ChoiceList(_choices, _picked, onPick: _accept),
          AnimatedBuilder(
            animation: _focus,
            builder: (context, child) => Container(
              decoration: BoxDecoration(
                color: t.base,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focus.hasFocus ? t.focus : t.borderStrong,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
              child: child,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_images.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                    child: Thumbnails(
                      _images.value,
                      onRemove: _images.removeAt,
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Builder(
                      builder: (button) => BoxButton(
                        tooltip: 'Mention a file or attach an image',
                        onPressed: () => _plus(button),
                        child: Icon(
                          Icons.add,
                          size: 18,
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Focus(
                        onKeyEvent: _onKey,
                        skipTraversal: true,
                        child: TextField(
                          controller: _text,
                          focusNode: _focus,
                          autofocus: true,
                          minLines: 1,
                          maxLines: 10,
                          style: theme.ui(t.text),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: chat.busy
                                ? 'Claude is working…'
                                : widget.hint,
                            hintStyle: theme.ui(t.textMuted),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (chat.started != null)
                      BoxButton(
                        tooltip: 'Stop (esc)',
                        onPressed: () => stopTurn(context, chat, widget.daemon),
                        child: StopIcon(color: t.textSecondary),
                      )
                    else if ((_text.text.trim().isNotEmpty ||
                            _images.value.isNotEmpty) &&
                        !chat.busy)
                      BoxButton(
                        tooltip: 'Send (⏎)',
                        onPressed: _send,
                        child: Icon(
                          Icons.keyboard_return,
                          size: 16,
                          color: t.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Pickers(
            options: chat.config,
            onPick: (id, value) =>
                widget.daemon.setConfigOption(chat.id, id, value),
          ),
        ],
      ),
    );
  }
}
