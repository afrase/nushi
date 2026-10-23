import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'composer_parts.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'images.dart';
import 'menu.dart';
import 'pickers.dart';
import 'replies.dart';
import 'reply_cards.dart';
import 'theme/theme.dart';
import 'thinking.dart';
import 'widgets.dart';
import 'worktree.dart';

/// The prompt box: "+" on its left mentions a file or attaches images
/// (⌘V and dropping work too), and on its right a send button once there
/// is something to send, or a stop button while a turn runs. Reply cards
/// and attached images show above the text; the replies go first in the
/// message. Under it, the agent's pickers. Enter sends,
/// Shift-Enter starts a line; `/` completes the agent's commands and `@`
/// the folder's files (sent as links); Up in an empty box brings back the
/// last prompt.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.chat,
    required this.daemon,
    required this.replies,
    this.quote,
    this.attachments,
    this.hint = 'Type / for commands',
    this.folder = false,
  });

  final ChatState chat;
  final Daemon daemon;

  /// Text to quote in the box (a side chat's start), cursor after it;
  /// taken and cleared.
  final ValueNotifier<String?>? quote;

  /// The replies to send with the next message.
  final Replies replies;

  /// The images to send with the prompt; the box keeps its own if null.
  final Attachments? attachments;
  final String hint;

  /// Whether a chat without messages shows its folder under the box.
  final bool folder;

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
    widget.replies.addListener(_repliesChanged);
    _text.addListener(_complete);
    widget.quote?.addListener(_quote);
    _quote(); // one given before the box was built
  }

  void _imagesChanged() => setState(() {});

  int _replyCount = 0;
  void _repliesChanged() {
    if (widget.replies.value.length > _replyCount) _focus.requestFocus();
    setState(() => _replyCount = widget.replies.value.length);
  }

  @override
  void dispose() {
    _images.removeListener(_imagesChanged);
    widget.replies.removeListener(_repliesChanged);
    if (widget.attachments == null) _images.dispose();
    widget.quote?.removeListener(_quote);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _quote() {
    final q = widget.quote?.value;
    if (q == null) return;
    widget.quote!.value = null;
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
        for (final n in rankChoices(names.keys, m[1]!))
          (label: '/$n', detail: names[n]!.description, insert: '/$n '),
      ];
      _token = (0, caret);
    } else if (RegExp(r'(^|\s)@(\S*)$').firstMatch(before) case final m?) {
      final folder = widget.chat.folder;
      final files = _filesOf == folder ? _files : null;
      if (files == null) {
        _files = const [];
        _filesOf = folder;
        widget.daemon.client.listFiles(ListFilesRequest(folder: folder)).then((
          r,
        ) {
          _files = r.paths;
          if (mounted) _complete();
        }, onError: (_) => _files = null);
      }
      choices = [
        for (final f in rankChoices(files ?? const [], m[2]!))
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
      final (replies, text) = splitReplies(last.text);
      widget.replies.value = replies;
      _text.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    final images = _images.value;
    final replies = widget.replies.value;
    if (text.isEmpty && images.isEmpty && replies.isEmpty || widget.chat.busy) {
      return;
    }
    final files = [
      for (final f in _mentions)
        if (text.contains('@$f')) f,
    ];
    _text.clear();
    _images.clear();
    widget.replies.value = const [];
    _mentions.clear();
    _lastFiles = files;
    try {
      await widget.daemon.client.sendPrompt(
        SendPromptRequest(
          chatId: widget.chat.id,
          text: withReplies(replies, text),
          files: files,
          images: images,
        ),
      );
    } on Object catch (e) {
      _text.text = text;
      _images.value = images;
      widget.replies.value = replies;
      if (mounted) showError(context, e);
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
    final theme = NushiTheme.of(context), t = theme.t;
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
                  color: _focus.hasFocus ? t.textMuted : t.borderStrong,
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: child,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_images.value.isNotEmpty || widget.replies.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ReplyCards(widget.replies, onDone: _focus.requestFocus),
                        Thumbnails(_images.value, onRemove: _images.removeAt),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Menu(
                      entries: [
                        MenuEntry('Mention a file', onPick: _mention),
                        MenuEntry(
                          'Image…',
                          onPick: chat.canImages
                              ? () => tryOrShow(context, _images.pick)
                              : null,
                          tooltip: chat.canImages
                              ? ''
                              : 'Claude doesn’t take images in this chat',
                        ),
                      ],
                      builder: (context, open) => boxButton(
                        'Mention a file or attach an image',
                        open,
                        Icon(Icons.add, size: 18, color: t.textSecondary),
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
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            hintText: chat.busy
                                ? 'Claude is working…'
                                : widget.hint,
                            border: InputBorder.none,
                            // One line (18.2) is as tall as the buttons.
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (chat.started != null)
                      boxButton(
                        'Stop (esc)',
                        () => stopTurn(context, chat, widget.daemon),
                        stopIcon(t.textSecondary),
                      )
                    else if ((_text.text.trim().isNotEmpty ||
                            _images.value.isNotEmpty ||
                            widget.replies.value.isNotEmpty) &&
                        !chat.busy)
                      boxButton(
                        'Send (⏎)',
                        _send,
                        Icon(
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
            leading: widget.folder && chat.fresh && !chat.archived
                ? NewChatBar(chat: chat, daemon: widget.daemon)
                : null,
            options: chat.config,
            onPick: (id, value) => widget.daemon.client.setConfigOption(
              SetConfigOptionRequest(
                chatId: chat.id,
                configId: id,
                value: value,
              ),
            ),
            onClose: _focus.requestFocus,
          ),
        ],
      ),
    );
  }
}
