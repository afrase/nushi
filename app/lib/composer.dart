import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/attached_files.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_column.dart';
import 'package:nushi/completions.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/composer_plus.dart';
import 'package:nushi/copy_command.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/grow.dart';
import 'package:nushi/images.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pickers.dart';
import 'package:nushi/plan_view.dart';
import 'package:nushi/queue.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/rewind_picker.dart';
import 'package:nushi/run_text.dart';
import 'package:nushi/spell_check.dart';
import 'package:nushi/spell_menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/worktree.dart';

/// The composer: "+" on its left attaches files or photos (⌘U; ⌘V and
/// dropping work too: [attachFiles]), mentions a file or offers the
/// commands ([PlusMenu]), and on its right a send button once there
/// is something to send, or a stop button while a turn runs. Reply cards
/// and attached images show above the text; the replies go first in the
/// message. Under it, the agent's pickers. Enter sends (⌘⏎ stops and sends
/// while a turn runs), Shift-Enter starts a line ([isSendKey]); `/` completes the
/// agent's commands and `@` the folder's files (sent as links); Up in an
/// empty box brings back the last prompt; Esc Esc lists your messages to
/// rewind to (on a Mac). While a message is on its way back to the box
/// ([ChatState.rewinding]) the box is read-only and sends nothing.
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
  final GlobalKey _box = GlobalKey(
    debugLabel: 'box',
  ); // the + menu opens over it
  late final Draft _draft = widget.chat.draft;
  late final TextEditingController _text = _draft.text;
  late final _completions = Completions(widget.chat, widget.daemon);
  Set<String> get _mentions => _draft.mentions; // files picked with @
  late final Attachments _images = _draft.images;
  Timer? _esc; // a first Esc's time to be followed by a second
  bool _built = false; // the box has been built once
  late final _spell = SpellCheck(_draft.text, widget.chat, _focus);

  @override
  void initState() {
    super.initState();
    _draft.addListener(_draftChanged);
    _replyCount = _draft.replies.value.length;
    _completions.addListener(_imagesChanged);
    _spell.addListener(_imagesChanged); // marks that came without typing
    _draft.quote.addListener(_quote);
    _quote(); // one given before the box was built
    _draft.put.addListener(_put);
    _put();
    widget.chat.rewinding.addListener(_imagesChanged);
    widget.chat.takeBack.addListener(_takeBack);
    _takeBack(); // one taken back while the box wasn't there
  }

  void _imagesChanged() => setState(() {}); // and completions, and the lock

  bool get _locked => widget.chat.rewinding.value;

  int _replyCount = 0;

  /// The draft changed: a card added takes the focus to the box.
  void _draftChanged() {
    if (_draft.replies.value.length > _replyCount) _focus.requestFocus();
    setState(() => _replyCount = _draft.replies.value.length);
  }

  @override
  void dispose() {
    _draft.removeListener(_draftChanged);
    _draft.quote.removeListener(_quote);
    _draft.put.removeListener(_put);
    widget.chat.rewinding.removeListener(_imagesChanged);
    widget.chat.takeBack.removeListener(_takeBack);
    _esc?.cancel();
    _completions.dispose();
    _spell.dispose();
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

  /// Puts the draft's [Draft.put] in the box, after a blank line when it
  /// holds text, and takes the focus there.
  void _put() {
    final p = _draft.put.value;
    if (p == null) return;
    _draft.put.value = null;
    final before = _text.text.trim().isEmpty
        ? ''
        : '${_text.text.trimRight()}\n\n';
    final text = '$before$p';
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    // Locked, ⏎ does nothing; the rest goes on to the read-only field and
    // the chat: moving, selecting, copying, Esc.
    if (_locked) {
      if (e is KeyUpEvent) return KeyEventResult.ignored;
      return isSendKey(e) || isLineKey(e)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (_spell.menu.onKey(e)) return KeyEventResult.handled;
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final esc = key == LogicalKeyboardKey.escape;
    if (esc && e is KeyRepeatEvent) return KeyEventResult.ignored;
    final second = esc && (_esc?.isActive ?? false);
    _esc?.cancel();
    _esc = null;
    // An Esc that closes the choices isn't the first of two.
    if (_completions.onKey(key, shift: shift)) return KeyEventResult.handled;
    if (esc && !TouchTargets.of(context)) {
      if (second) {
        unawaited(pickRewind(context, widget.daemon, widget.chat));
        return KeyEventResult.handled;
      }
      _esc = Timer(escEscWithin, () {});
      return KeyEventResult.ignored; // and goes on: it stops a turn
    }
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final enter = enterKey(e, _text, () => unawaited(_send(now: meta)));
    if (enter == KeyEventResult.handled) return enter;
    if (attachKey.accepts(e, HardwareKeyboard.instance)) {
      unawaited(_attach());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV && meta && !kIsWeb) {
      // Text, if any, pastes as usual.
      unawaited(attached(context, pasteFiles(widget.chat, api: _api)));
    }
    if (key == LogicalKeyboardKey.arrowUp && _text.text.isEmpty) {
      unawaited(_recall());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  int get _api => widget.daemon.daemonApi;

  /// Up in an empty box: your last message back in it, with its files and
  /// the saved uploads. A long last turn can start above a long chat's
  /// recent part: the pages back to its message first (ADR 0026).
  Future<void> _recall() async {
    final chat = widget.chat;
    bool mine(Item it) => it.kind == ItemKind.ITEM_KIND_USER_MESSAGE;
    if (!chat.items.any(mine) && chat.older > 0) {
      await widget.daemon.loadOlder(chat, until: mine);
      if (!mounted || _text.text.isNotEmpty) return; // typed meanwhile
    }
    final last = chat.items.lastWhere(mine, orElse: Item.new);
    _restore(last.text, last.files, const []);
  }

  /// Add files or photos: the open panel (the phone's picker), then what
  /// was picked into the box.
  Future<void> _attach() async {
    if (_picking) return; // one panel at a time
    _picking = true;
    try {
      final picked = await pickFiles();
      if (picked.isEmpty || !mounted) return;
      await attached(context, attachFiles(widget.chat, picked, api: _api));
      if (mounted) _focus.requestFocus();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      _picking = false;
    }
  }

  /// The open panel is open ([_attach]).
  bool _picking = false;

  /// Puts a message back in the box, after what is there: its replies as
  /// cards, its text, its files (those its text mentions as @mentions, the
  /// others as file cards) and images.
  void _restore(String message, List<String> files, List<ImageData> images) {
    final (replies, text) = splitReplies(message);
    _draft.replies.value = [..._draft.replies.value, ...replies];
    final folder = widget.chat.folder;
    for (final f in files) {
      if (mentionsPath(text, f)) {
        _mentions.add(f);
      } else {
        final card = AttachedFile.at(absoluteIn(folder, f));
        if (!_draft.files.value.contains(card)) {
          _draft.files.value = [..._draft.files.value, card];
        }
      }
    }
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
    if (m.toSubagentStop) return; // a stop has nothing to edit
    _restore(m.text, m.files, m.images);
    if (m.toSubagent.isNotEmpty) {
      _draft.toSubagent.value = (m.toSubagent, m.toSubagentName);
    } else if (m.toSubagentName.isNotEmpty) {
      // After the frame: one taken back while the box was away comes from
      // initState, where the messenger can't be looked up yet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showError(
          context,
          'This message was for ${m.toSubagentName}: send it from its pane.',
        );
      });
    }
  }

  /// [act] on a queued message; nothing while the box is locked.
  void Function(QueuedMessage) _unlocked(
    Future<void> Function(QueuedMessage) act,
  ) => (m) {
    if (!_locked) unawaited(act(m));
  };

  /// Takes a queued message back from the daemon, to edit unless [drop].
  Future<void> _unqueue(QueuedMessage m, {bool drop = false}) =>
      tryOrShow(context, () async {
        final r = await widget.daemon.client.unqueue(
          UnqueueRequest(chatId: widget.chat.id, id: m.id),
        );
        if (!drop) _restoreMessage(r.message);
      });

  /// Sends a queued message now: out of the queue, then in place of the
  /// running turn (Stop and send). Should the send fail, it's back in the box.
  Future<void> _sendNow(QueuedMessage m) => tryOrShow(context, () async {
    final r = await widget.daemon.client.unqueue(
      UnqueueRequest(chatId: widget.chat.id, id: m.id),
    );
    final q = r.message;
    try {
      await widget.daemon.sendPrompt(
        SendPromptRequest(
          chatId: widget.chat.id,
          text: q.text,
          files: q.files,
          images: q.images,
          queue: widget.chat.busy,
          now: widget.chat.started != null,
          toSubagent: q.toSubagent,
        ),
      );
    } on Object {
      _restoreMessage(q);
      rethrow;
    }
  });

  /// Sends the box's message; while the agent works it waits in the
  /// chat's queue, or with [now] stops the turn and goes at once.
  Future<void> _send({bool now = false}) async {
    if (_locked) return;
    // Before any wait: a browser copies only straight from the tap.
    if (copyAsked(_text.text.trim()) case final n?) {
      _text.clear();
      await copyMessage(context, widget.chat, n);
      return;
    }
    // What was pasted or dropped a moment ago goes with it.
    await _images.ready();
    final busy = widget.chat.busy;
    if (!_draft.hasMessage) return;
    final m = _draft.take();
    final text = m.text;
    final (paths, uploads) = sendable(m.files, widget.chat.folder);
    // The mentions still in the text, then the cards: one both is listed once.
    final mentioned = [
      for (final f in m.mentions)
        if (mentionsPath(text, f)) f,
    ];
    final files = [...mentioned, ...paths.where((p) => !mentioned.contains(p))];
    final chat = widget.chat;
    final message = withOutputs(withReplies(m.replies, text), m.outputs);
    // To an idle chat it shows in the transcript at once, faint until the
    // daemon's echo; not a queued one (a pill) nor one for a subagent.
    final shown = !busy && m.toSubagent == null && !chat.asleep
        ? chat.outbox.send(
            message,
            m.images,
            files: files, // uploads once saved
          )
        : null;
    try {
      final r = await widget.daemon.sendPrompt(
        SendPromptRequest(
          chatId: widget.chat.id,
          text: message,
          files: files,
          images: m.images,
          uploads: uploads,
          queue: busy,
          now: now && widget.chat.started != null,
          toSubagent: m.toSubagent?.$1,
        ),
      );
      // A command the daemon ran (Claude's /plan) has no echo to wait for.
      if (shown != null) {
        r.ranCommand ? chat.outbox.ran(shown) : chat.outbox.sent(shown);
      }
    } on Object catch (e) {
      // It fades out of the transcript as it goes back in the box.
      if (shown != null) {
        final still = mounted && reduceMotion(context);
        chat.outbox.unsend(shown, fade: still ? Duration.zero : Motion.exit);
      }
      // Back in the draft (it outlives the box), before what was typed since.
      _draft.putBack(m);
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final touch = TouchTargets.of(context);
    // Buttons pop in once the box is there, not with it.
    final pop = _built;
    _built = true;
    final written = !_locked && _draft.hasMessage;
    return ChatColumn(
      child: Padding(
        padding: touch
            ? const EdgeInsets.fromLTRB(16, 4, 16, 8)
            : const EdgeInsets.fromLTRB(
                NushiTheme.gutter,
                4,
                NushiTheme.gutter,
                12,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The lines over the box grow in and fold away (grow.dart).
            GrowLine(
              child: switch (turnPlan(chat.items)) {
                final plan? when chat.busy => PlanStatus(plan),
                _ => null,
              },
            ),
            GrowLine(
              child: chat.queue.isEmpty
                  ? null
                  : QueuePills(
                      chat,
                      onEdit: _unlocked(_unqueue),
                      onRemove: _unlocked((m) => _unqueue(m, drop: true)),
                      onSendNow: _unlocked(_sendNow),
                    ),
            ),
            GrowLine(
              child: chat.error.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        chat.error,
                        style: theme.ui(t.crashed, size: 12),
                      ),
                    ),
            ),
            GrowLine(
              child: _completions.choices.isEmpty || _locked
                  ? null
                  : ChoiceList(
                      _completions.choices,
                      _completions.picked,
                      onPick: _completions.accept,
                    ),
            ),
            AnimatedBuilder(
              animation: _focus,
              builder: (context, child) => Container(
                key: _box,
                decoration: BoxDecoration(
                  color: t.base,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _focus.hasFocus ? t.textMuted : t.borderStrong,
                  ),
                ),
                // 48 high on the Mac with one line, the buttons 28 (ADR 0072).
                padding: touch
                    ? const EdgeInsets.all(6)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: child,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GrowLine(
                    child:
                        _images.value.isEmpty &&
                            _draft.files.value.isEmpty &&
                            _draft.replies.value.isEmpty &&
                            _draft.outputs.value.isEmpty &&
                            _draft.toSubagent.value == null
                        ? null
                        : DraftCards(
                            _draft,
                            chat: chat,
                            onDone: _focus.requestFocus,
                          ),
                  ),
                  Row(
                    children: [
                      PlusMenu(
                        box: _box,
                        chat: chat,
                        api: _api,
                        locked: _locked,
                        onAttach: () => unawaited(_attach()),
                        onMention: () {
                          _completions.mention();
                          _focus.requestFocus();
                        },
                        // The focus first: taking it puts the cursor at the
                        // end, and the commands want it after the slash.
                        onSlash: () {
                          _focus.requestFocus();
                          _completions.slash();
                        },
                      ),
                      Expanded(
                        child: SpellArea(
                          _spell.menu,
                          child: Focus(
                            onKeyEvent: _onKey,
                            skipTraversal: true,
                            child: TextField(
                              controller: _text,
                              focusNode: _focus,
                              readOnly: _locked,
                              onTap: _spell.menu.tapped,
                              contextMenuBuilder: _spell.menu.toolbar,
                              autofocus: !touch, // no keyboard popping up
                              minLines: 1,
                              // A phone's keyboard leaves the transcript little
                              // room: past six lines the field scrolls.
                              maxLines: touch ? 6 : 10,
                              style: theme.ui(t.text),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText: _locked
                                    ? rewindHint(chat)
                                    : !chat.busy
                                    ? widget.hint
                                    : touch
                                    ? 'Queue a message, or stop and send'
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
                      ),
                      SendButtons(
                        chat,
                        widget.daemon,
                        written: written,
                        pop: pop,
                        onSend: _send,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: touch ? 4 : 8),
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
      ),
    );
  }
}
