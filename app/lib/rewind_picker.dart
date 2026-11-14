import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// Esc Esc in the prompt box, as in Claude Code: a list of your messages to
// rewind the chat to.

/// How soon a second Esc must follow the first.
// design: a double press, as macOS times one
const escEscWithin = Duration(milliseconds: 500);

/// Lists [chat]'s messages that can be rewound to ([RewindPicker]) and
/// rewinds to just before the one picked, without asking again: the list
/// is the confirmation. The message goes back in the box.
Future<void> pickRewind(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
) async {
  final item = await showDialog<Item>(
    context: context,
    builder: (_) => RewindPicker(chat: chat, daemon: daemon),
  );
  if (item == null || !context.mounted) return;
  await rewindTo(context, daemon, chat, item);
}

/// Your messages in [chat] that it can be rewound to, newest first, then
/// those in [earlier] (items before what it has loaded).
List<Item> rewindChoices(ChatState chat, [List<Item> earlier = const []]) {
  final have = {for (final it in chat.items) it.id};
  return [
    for (final it in [
      ...earlier.where((it) => !have.contains(it.id)),
      ...chat.items,
    ].reversed)
      if (it.kind == ItemKind.ITEM_KIND_USER_MESSAGE && canRewindTo(chat, it))
        it,
  ];
}

/// A message in one line: its first line of text (after any replies'
/// quotes), else a reply's, else its images.
String rewindLine(Item it) {
  final (replies, text) = splitReplies(it.text);
  for (final t in [text, for (final r in replies) r.text]) {
    for (final l in t.split('\n')) {
      if (l.trim().isNotEmpty) return l.trim();
    }
  }
  return switch (it.images.length) {
    0 => it.text.trim(),
    1 => 'An image',
    final n => '$n images',
  };
}

/// The rewind list: a field that filters, your messages under it (one line
/// each and when it was sent), and the warning that files stay as they
/// are. ↑↓ move, ⏎ or a click picks (the dialog pops with the message),
/// Esc closes. While a turn runs it says to stop it first, and lists the
/// messages once it has stopped. Those above a long chat's loaded part
/// come from [daemon] as it lists, into the list only: the transcript
/// would lay them all out (ADR 0026).
class RewindPicker extends StatefulWidget {
  const new({required this.chat, required this.daemon, super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<RewindPicker> createState() => _RewindPickerState();
}

class _RewindPickerState extends State<RewindPicker> {
  final _text = TextEditingController();
  final GlobalKey<State<StatefulWidget>> _lit = GlobalKey();
  int _at = 0;
  List<Item> _earlier = const []; // before the chat's loaded items
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  @override
  void dispose() {
    _gone = true;
    _text.dispose();
    super.dispose();
  }

  /// The items before the chat's loaded ones, a page of as many as the
  /// daemon gives at a time, until the start or the list closes. A page
  /// that fails leaves the list as it is.
  Future<void> _fetch() async {
    final chat = widget.chat;
    var older = chat.older;
    var first = chat.items.firstOrNull?.id;
    try {
      while (older > 0 && first != null) {
        final page = await widget.daemon.client.getChatItems(
          GetChatItemsRequest(
            chatId: chat.id,
            before: first,
            limit: 500,
            imageRefs: true,
          ),
        );
        if (_gone || !mounted || page.items.isEmpty) return;
        setState(() => _earlier = [...page.items, ..._earlier]);
        older = page.older;
        first = page.items.first.id;
      }
    } on Object {
      return;
    }
  }

  List<Item> get _shown {
    final q = _text.text.trim().toLowerCase();
    return [
      for (final it in rewindChoices(widget.chat, _earlier))
        if (it.text.toLowerCase().contains(q)) it,
    ];
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final shown = _shown;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowUp
          when shown.isNotEmpty:
        final step = e.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
        setState(() => _at = (_at + step) % shown.length);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_lit.currentContext case final c?) Scrollable.ensureVisible(c);
        });
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when _at < shown.length:
        Navigator.pop(context, shown[_at]);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.chat, // a turn ending lists the messages
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final chat = widget.chat;
      final shown = _shown;
      _at = _at.clamp(0, shown.isEmpty ? 0 : shown.length - 1);
      final now = clock();
      final none = switch (chat) {
        _ when chat.busy && chat.stopping => 'Stopping the turn…',
        _ when chat.busy => 'Stop the turn first',
        _ when !chat.canRewind || chat.archived =>
          '${chat.agentName} can’t rewind this chat',
        _ when shown.isEmpty && _text.text.trim().isNotEmpty =>
          'No message matches',
        _ when shown.isEmpty => 'No message to rewind to',
        _ => null,
      };
      return Dialog(
        alignment: const Alignment(0, -0.6),
        child: SizedBox(
          width: 560,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Focus(
                  onKeyEvent: _onKey,
                  skipTraversal: true,
                  child: TextField(
                    controller: _text,
                    autofocus: true,
                    style: theme.ui(t.text),
                    onChanged: (_) => setState(() => _at = 0),
                    decoration: const InputDecoration(
                      hintText: 'Rewind to before…',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.history, size: 15),
                      prefixIconConstraints: BoxConstraints(minWidth: 28),
                    ),
                  ),
                ),
                const Divider(height: 9),
                if (none != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(none, style: theme.ui(t.textMuted)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      primary: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, it) in shown.indexed)
                            _row(theme, it, now, lit: i == _at),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 9),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                  child: Text(
                    'Files aren’t rewound: ${chat.agentName}’s changes since '
                    'then stay.',
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _row(NushiTheme theme, Item it, DateTime now, {required bool lit}) {
    final t = theme.t;
    final sent = DateTime.fromMillisecondsSinceEpoch(it.sent.toInt());
    return Tap(
      key: lit ? _lit : null,
      onTap: () => Navigator.pop(context, it),
      selected: lit,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rewindLine(it),
              style: theme.ui(t.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (it.sent > 0)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                ago(now.difference(sent), sent),
                style: theme.ui(t.textMuted, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}
