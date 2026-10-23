import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'completions.dart';
import 'composer_parts.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'images.dart';
import 'menu.dart';
import 'pickers.dart';
import 'queue.dart';
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
  late final _completions = Completions(
    _text,
    () => widget.chat,
    widget.daemon,
  );
  Set<String> get _mentions => _completions.mentions; // files picked with @
  List<String> _lastFiles = []; // the last prompt's, for Up
  late final _images = widget.attachments ?? Attachments();

  @override
  void initState() {
    super.initState();
    _images.addListener(_imagesChanged);
    widget.replies.addListener(_repliesChanged);
    _completions.addListener(_imagesChanged);
    widget.quote?.addListener(_quote);
    _quote(); // one given before the box was built
    widget.chat.takeBack.addListener(_takeBack);
  }

  void _imagesChanged() => setState(() {}); // and completions

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
    widget.chat.takeBack.removeListener(_takeBack);
    _completions.dispose();
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

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (_completions.onKey(key, shift: shift)) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.enter && !shift) {
      _send(now: HardwareKeyboard.instance.isMetaPressed);
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
      _restore(last.text, _lastFiles, const []);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Puts a message back in the box, after what is there: its replies as
  /// cards, its text, its file mentions and images.
  void _restore(String message, List<String> files, List<ImageData> images) {
    final (replies, text) = splitReplies(message);
    widget.replies.value = [...widget.replies.value, ...replies];
    _mentions.addAll(files);
    _images.value = [..._images.value, ...images];
    final before = _text.text.trim();
    final all = [if (before.isNotEmpty) before, if (text.isNotEmpty) text];
    final joined = all.join('\n\n');
    _text.value = TextEditingValue(
      text: joined,
      selection: TextSelection.collapsed(offset: joined.length),
    );
    _focus.requestFocus();
  }

  void _takeBack() {
    final m = widget.chat.takeBack.value;
    if (m == null) return;
    widget.chat.takeBack.value = null;
    _restore(m.text, m.files, m.images);
  }

  /// Takes a queued message back from the daemon, to edit unless [drop].
  Future<void> _unqueue(QueuedMessage m, {bool drop = false}) =>
      tryOrShow(context, () async {
        final r = await widget.daemon.client.unqueue(
          UnqueueRequest(chatId: widget.chat.id, id: m.id),
        );
        if (!drop) _restore(r.message.text, r.message.files, r.message.images);
      });

  /// Sends the box's message; while the agent works it waits in the
  /// chat's queue, or with [now] stops the turn and goes at once.
  Future<void> _send({bool now = false}) async {
    final text = _text.text.trim();
    final images = _images.value;
    final replies = widget.replies.value;
    final busy = widget.chat.busy;
    if (text.isEmpty && images.isEmpty && replies.isEmpty ||
        busy && !widget.daemon.canQueue) {
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
          queue: busy,
          now: now && widget.chat.started != null,
        ),
      );
    } on Object catch (e) {
      _text.text = text;
      _images.value = images;
      widget.replies.value = replies;
      if (mounted) showError(context, e);
    }
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
          if (turnPlan(chat.items) case final plan? when chat.busy)
            PlanStatus(plan),
          if (chat.queue.isNotEmpty)
            QueuePills(
              chat,
              onEdit: _unqueue,
              onRemove: (m) => _unqueue(m, drop: true),
            ),
          if (chat.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(chat.error, style: theme.ui(t.crashed, size: 12)),
            ),
          if (_completions.choices.isNotEmpty)
            ChoiceList(
              _completions.choices,
              _completions.picked,
              onPick: _completions.accept,
            ),
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
                        MenuEntry(
                          'Mention a file',
                          onPick: () {
                            _completions.mention();
                            _focus.requestFocus();
                          },
                        ),
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
                            hintText: !chat.busy
                                ? widget.hint
                                : widget.daemon.canQueue
                                ? 'Claude is working: ⏎ queues, ⌘⏎ stops it and sends'
                                : 'Claude is working…',
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
