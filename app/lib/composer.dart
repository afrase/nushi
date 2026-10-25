import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/completions.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/pickers.dart';
import 'package:nushi/queue.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/reply_cards.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/thinking.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/worktree.dart';

/// The prompt box: "+" on its left mentions a file or attaches images
/// (⌘V and dropping work too), and on its right a send button once there
/// is something to send, or a stop button while a turn runs. Reply cards
/// and attached images show above the text; the replies go first in the
/// message. Under it, the agent's pickers. Enter sends,
/// Shift-Enter starts a line; `/` completes the agent's commands and `@`
/// the folder's files (sent as links); Up in an empty box brings back the
/// last prompt.
class Composer extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    super.key,
    this.hint = 'Type / for commands',
    this.folder = false,
  });

  /// The chat; what's written is its draft, which outlives the box.
  final ChatState chat;
  final Daemon daemon;
  final String hint;

  /// Whether a chat without messages shows its folder under the box.
  final bool folder;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _focus = FocusNode();
  late final Draft _draft = widget.chat.draft;
  late final TextEditingController _text = _draft.text;
  late final _completions = Completions(
    _text,
    _draft.mentions,
    () => widget.chat,
    widget.daemon,
  );
  Set<String> get _mentions => _draft.mentions; // files picked with @
  List<String> _lastFiles = []; // the last prompt's, for Up
  late final Attachments _images = _draft.images;

  @override
  void initState() {
    super.initState();
    _images.addListener(_imagesChanged);
    _draft.replies.addListener(_repliesChanged);
    _replyCount = _draft.replies.value.length;
    _completions.addListener(_imagesChanged);
    _draft.relay.addListener(_imagesChanged);
    _draft.quote.addListener(_quote);
    _quote(); // one given before the box was built
    widget.chat.takeBack.addListener(_takeBack);
    _takeBack(); // one taken back while the box wasn't there
  }

  void _imagesChanged() => setState(() {}); // and completions

  int _replyCount = 0;
  void _repliesChanged() {
    if (_draft.replies.value.length > _replyCount) _focus.requestFocus();
    setState(() => _replyCount = _draft.replies.value.length);
  }

  @override
  void dispose() {
    _images.removeListener(_imagesChanged);
    _draft.relay.removeListener(_imagesChanged);
    _draft.replies.removeListener(_repliesChanged);
    _draft.quote.removeListener(_quote);
    widget.chat.takeBack.removeListener(_takeBack);
    _completions.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _quote() {
    final q = _draft.quote.value;
    if (q == null) return;
    _draft.quote.value = null;
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
      unawaited(_send(now: HardwareKeyboard.instance.isMetaPressed));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV &&
        HardwareKeyboard.instance.isMetaPressed &&
        widget.chat.canImages) {
      unawaited(
        tryOrShow(context, _images.paste),
      ); // text, if any, pastes as usual
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
    _draft.replies.value = [..._draft.replies.value, ...replies];
    _mentions.addAll(files);
    _images.value = [..._images.value, ...images];
    final before = _text.text.trim();
    final all = [if (before.isNotEmpty) before, if (text.isNotEmpty) text];
    final joined = all.join('\n\n');
    _text.value = TextEditingValue(
      text: joined,
      selection: TextSelection.collapsed(offset: joined.length),
    );
    if (mounted) _focus.requestFocus();
  }

  void _takeBack() {
    final m = widget.chat.takeBack.value;
    if (m == null) return;
    widget.chat.takeBack.value = null;
    _restoreMessage(m);
  }

  /// Puts a message taken back in the box: one for a subagent stays for it,
  /// or, when Nushi can't tell which one (a replayed message), says so.
  void _restoreMessage(QueuedMessage m) {
    _restore(m.text, m.files, m.images);
    if (m.toSubagent.isNotEmpty) {
      _draft.relay.value = (m.toSubagent, m.relayTo);
    } else if (m.relayTo.isNotEmpty && mounted) {
      showError(
        context,
        'This message was for ${m.relayTo}: send it from its pane.',
      );
    }
  }

  /// Takes a queued message back from the daemon, to edit unless [drop].
  Future<void> _unqueue(QueuedMessage m, {bool drop = false}) =>
      tryOrShow(context, () async {
        final r = await widget.daemon.client.unqueue(
          UnqueueRequest(chatId: widget.chat.id, id: m.id),
        );
        if (!drop) _restoreMessage(r.message);
      });

  /// Sends the box's message; while the agent works it waits in the
  /// chat's queue, or with [now] stops the turn and goes at once.
  Future<void> _send({bool now = false}) async {
    await _images.ready(); // an image pasted a moment ago goes with it
    final text = _text.text.trim();
    final images = _images.value;
    final replies = _draft.replies.value;
    final mentions = {..._mentions};
    final relay = _draft.relay.value;
    final busy = widget.chat.busy;
    if (text.isEmpty && images.isEmpty && replies.isEmpty) return;
    final files = [
      for (final f in _mentions)
        if (text.contains('@$f')) f,
    ];
    _text.clear();
    _images.clear();
    _draft.replies.value = const [];
    _draft.relay.value = null;
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
          toSubagent: relay?.$1,
        ),
      );
    } on Object catch (e) {
      // Back in the draft (it outlives the box), before what was typed since.
      final since = _text.text.trim();
      _text.text = [text, if (since.isNotEmpty) since].join('\n\n');
      _images.value = [...images, ..._images.value];
      _draft.replies.value = [...replies, ..._draft.replies.value];
      _draft.relay.value ??= relay;
      _mentions.addAll(mentions);
      if (mounted) showError(context, e);
    }
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
                if (_images.value.isNotEmpty ||
                    _draft.replies.value.isNotEmpty ||
                    _draft.relay.value != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (_draft.relay.value case (_, final agent)?)
                          Chip(
                            label: Text('To $agent, through ${chat.agentName}'),
                            onDeleted: () => _draft.relay.value = null,
                            visualDensity: VisualDensity.compact,
                          ),
                        ReplyCards(_draft.replies, onDone: _focus.requestFocus),
                        Thumbnails(_images.value, onRemove: _images.removeAt),
                      ],
                    ),
                  ),
                Row(
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
                              : '${chat.agentName} doesn’t take images '
                                    'in this chat',
                        ),
                      ],
                      builder: (context, open) => boxButton(
                        'Add a file or image',
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
                                : '⏎ queues it, ⌘⏎ stops ${chat.agentName} '
                                      'and sends',
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
                            _draft.replies.value.isNotEmpty) &&
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
