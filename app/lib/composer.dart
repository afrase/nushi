import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'pickers.dart';
import 'theme/theme.dart';
import 'thinking.dart';
import 'widgets.dart';

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

/// A completion offered while typing: a slash command or a file.
typedef _Choice = ({String label, String detail, String insert});

/// The prompt box, with the agent's pickers and Send under it. Enter sends,
/// Shift-Enter starts a line; `/` completes the agent's commands and `@`
/// the folder's files (sent as links); Up in an empty box brings back the
/// last prompt.
class Composer extends StatefulWidget {
  const Composer({super.key, required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _mentions = <String>{}; // files picked with @
  List<String> _lastFiles = []; // the last prompt's, for Up
  List<String>? _files; // the folder's, fetched at the first @
  List<_Choice> _choices = [];
  int _picked = 0;
  (int, int)? _token; // where the text being completed starts and ends
  String _dismissed = ''; // the text Escape closed the choices for

  @override
  void initState() {
    super.initState();
    _text.addListener(_complete);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _complete() {
    final caret = _text.selection.baseOffset;
    final before = caret < 0 ? '' : _text.text.substring(0, caret);
    var choices = <_Choice>[];
    _token = null;
    if (RegExp(r'^/(\S*)$').firstMatch(before) case final m?) {
      final names = {for (final c in widget.chat.commands) c.name: c};
      choices = [
        for (final n in _rank(names.keys, m[1]!))
          (label: '/$n', detail: names[n]!.description, insert: '/$n '),
      ];
      _token = (0, caret);
    } else if (RegExp(r'(^|\s)@(\S*)$').firstMatch(before) case final m?) {
      final files = _files;
      if (files == null) {
        _files = const [];
        widget.daemon.listFiles(widget.chat.folder).then((f) {
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

  void _accept(_Choice c) {
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
    if (text.isEmpty || widget.chat.busy) return;
    final files = [
      for (final f in _mentions)
        if (text.contains('@$f')) f,
    ];
    _text.clear();
    _mentions.clear();
    _lastFiles = files;
    try {
      await widget.daemon.sendPrompt(widget.chat.id, text, files);
    } on Object catch (e) {
      _text.text = text;
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
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(NushiTheme.control),
      borderSide: BorderSide(color: c, width: w),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
            _ChoiceList(_choices, _picked, onPick: _accept),
          Focus(
            onKeyEvent: _onKey,
            skipTraversal: true,
            child: TextField(
              controller: _text,
              focusNode: _focus,
              autofocus: true,
              minLines: 2,
              maxLines: 10,
              style: theme.ui(t.text),
              decoration: InputDecoration(
                isDense: true,
                hintText: chat.busy ? 'Claude is working…' : 'Message Claude   @ file   / command   ⏎ send · ⇧⏎ newline',
                hintStyle: theme.ui(t.textMuted),
                filled: true,
                fillColor: t.base,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                enabledBorder: border(t.borderStrong, 1),
                focusedBorder: border(t.focus, 2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Pickers(
                    options: chat.config,
                    onPick: (id, value) =>
                        widget.daemon.setConfigOption(chat.id, id, value),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (chat.started != null)
                Button(
                  label: 'Stop',
                  hint: 'esc',
                  icon: Icons.stop,
                  kind: ButtonKind.danger,
                  height: 24,
                  onPressed: () => stopTurn(context, chat, widget.daemon),
                )
              else
                Button(
                  label: 'Send',
                  hint: '⏎',
                  kind: ButtonKind.primary,
                  height: 24,
                  onPressed: chat.busy ? null : _send,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The completions over the prompt box, the picked one highlighted.
class _ChoiceList extends StatelessWidget {
  const _ChoiceList(this.choices, this.picked, {required this.onPick});

  final List<_Choice> choices;
  final int picked;
  final void Function(_Choice) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.base,
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(NushiTheme.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in choices.indexed)
            Material(
              color: i == picked ? t.selected : Colors.transparent,
              borderRadius: BorderRadius.circular(NushiTheme.control),
              child: InkWell(
                onTap: () => onPick(c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: c.label,
                          style: theme.code(t.text, size: 12.5),
                        ),
                        if (c.detail.isNotEmpty)
                          TextSpan(
                            text: '   ${c.detail}',
                            style: theme.ui(t.textMuted, size: 12),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
