import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/code_run_view.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/file_cards.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/reply_cards.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Stops the chat's running turn. If the agent hasn't answered the last
/// message yet, the daemon takes it back too, for the composer, which is
/// locked until it's there.
Future<void> stopTurn(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async {
  if (chat.started == null || chat.stopping || chat.rewinding.value) return;
  chat.stopping = true;
  Future<void> stop() async {
    final r = await daemon.client.cancelTurn(
      CancelTurnRequest(chatId: chat.id, takeBack: true),
    );
    if (r.hasMessage()) chat.takeBack.value = r.message;
  }

  await tryOrShow(
    context,
    () => unanswered(chat) ? whileRewinding(chat, stop) : stop(),
  );
  chat.stopping = false;
}

/// What the locked box says ([ChatState.rewinding]), for a rewind or a Stop
/// taking the message back.
String rewindHint(ChatState chat) =>
    chat.stopping ? 'Taking your message back…' : 'Rewinding…';

/// Enter in a box that sends (the composer, a reply, the reply dialog, a
/// subagent's box, a review comment; the keypad's Enter too), one
/// rule for all of them: Enter sends, alone or with ⌘ (the usual "send" on a
/// Mac, as ⌘⏎ posts from GitHub's comment box); with ⇧, ⌥ or ⌃ it starts a
/// line. Nushi writes that line itself ([startLine]) and keeps the key from
/// the field, so there is one way for all and never two lines: left to
/// macOS's text input, a Flutter field starts one for ⇧ and ⌥ but types a
/// space for ⌃ (seen in a release build). A phone's Return is Enter
/// without them (the browser's keydown): it sends there too. Where Control
/// is the command key (Linux), Ctrl+Enter sends now, as ⌘⏎ does.
bool isSendKey(KeyEvent e) => _isEnter(e) && !_lineModifier;

/// Whether [e] is Enter with ⇧, ⌥ or ⌃ (not the command key), which starts
/// a line ([isSendKey]).
bool isLineKey(KeyEvent e) => _isEnter(e) && _lineModifier;

bool _isEnter(KeyEvent e) =>
    e is! KeyUpEvent &&
    (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter);

bool get _lineModifier {
  final k = HardwareKeyboard.instance;
  return k.isShiftPressed ||
      k.isAltPressed ||
      k.isControlPressed && commandKey != CommandKey.control;
}

/// A Markdown list item's start: its indent, and `1.`, `1)`, `-` or `*`
/// with a space after.
final _listItem = RegExp(r'^([ \t]*)(?:(\d{1,9})([.)])|([-*]))[ \t]+');

/// Puts a line break in [text] at its selection, in place of what's
/// selected, the cursor after it. A line that's a list item continues the
/// list, as GitHub's and Slack's boxes do: the new line starts with the next
/// number (`2. ` after `1. `) or the same bullet, at the same indent. On an
/// item with nothing in it yet, the line break ends the list instead: the
/// marker goes, and the line is left blank. One change to the text, so one
/// undo takes the line and its marker back.
void startLine(TextEditingController text) {
  final v = text.value;
  final s = v.selection.isValid
      ? v.selection
      : TextSelection.collapsed(offset: v.text.length);
  final from = s.start == 0 ? 0 : v.text.lastIndexOf('\n', s.start - 1) + 1;
  final to = v.text.indexOf('\n', s.end);
  final end = to < 0 ? v.text.length : to;
  final item = _listItem.firstMatch(v.text.substring(from, s.start));
  final (String put, int start, int stop) = switch (item) {
    null => ('\n', s.start, s.end),
    final m
        when m.end == s.start - from &&
            v.text.substring(s.end, end).trim().isEmpty =>
      ('', from, end),
    final m => ('\n${m[1]}${_nextMarker(m)}', s.start, s.end),
  };
  text.value = TextEditingValue(
    text: v.text.replaceRange(start, stop, put),
    selection: TextSelection.collapsed(offset: start + put.length),
  );
}

/// The marker of the item after [item]: its number and one, or its bullet.
String _nextMarker(RegExpMatch item) => switch (item[2]) {
  final n? => '${int.parse(n) + 1}${item[3]} ',
  null => '${item[4]} ',
};

/// Enter in a box that sends, by [isSendKey]'s rule: [send], or a line
/// started in [text]; any other key is left to the field.
KeyEventResult enterKey(
  KeyEvent e,
  TextEditingController text,
  VoidCallback send,
) {
  if (isSendKey(e)) {
    send();
  } else if (isLineKey(e)) {
    startLine(text);
  } else {
    return KeyEventResult.ignored;
  }
  return KeyEventResult.handled;
}

/// [child], a multi-line text field on [controller], with the composer's
/// keys ([isSendKey]): Enter (or ⌘⏎) runs [onEnter], ⇧⏎ (⌥⏎, ⌃⏎) starts a
/// line.
class EnterSends extends StatelessWidget {
  const new({
    required this.controller,
    required this.onEnter,
    required this.child,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onEnter;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    skipTraversal: true,
    onKeyEvent: (_, e) => enterKey(e, controller, onEnter),
    child: child,
  );
}

/// The cards over the box's text: the subagent it goes to, the replies,
/// the outputs, the files and the images of [draft]. Shown only when
/// there are some.
class DraftCards extends StatelessWidget {
  const new(this.draft, {required this.chat, required this.onDone, super.key});

  final Draft draft;
  final ChatState chat;

  /// A reply card done with (the focus back to the box).
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (draft.toSubagent.value case (_, final agent)?)
          _ToChip(
            'To $agent, through ${chat.agentName}',
            onRemove: () => draft.toSubagent.value = null,
          ),
        // Only when there are some: an empty one still takes a spacing,
        // which put the first row 6pt right of the rows wrapped under it.
        if (draft.replies.value.isNotEmpty)
          ReplyCards(draft.replies, onDone: onDone),
        for (final o in draft.outputs.value)
          OutputCard(
            o,
            onRemove: () => draft.outputs.value = [
              ...draft.outputs.value.where((n) => n != o),
            ],
          ),
        for (final f in draft.files.value)
          FileCard(
            f,
            onRemove: () =>
                draft.files.value = [...draft.files.value.where((n) => n != f)],
          ),
        if (draft.images.value.isNotEmpty)
          Thumbnails(draft.images.value, onRemove: draft.images.removeAt),
      ],
    ),
  );
}

/// Whom the box's message is for, when not the chat's agent: a pill on the
/// card's lifted fill, with its ×.
class _ToChip extends StatelessWidget {
  const new(this.label, {required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: t.lifted,
        borderRadius: BorderRadius.circular(NushiTheme.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.text, size: 12),
            ),
          ),
          IconTap(Icons.close, size: 13, tooltip: 'Remove', onTap: onRemove),
        ],
      ),
    );
  }
}

/// The end of the box's row (ADR 0111): while a turn runs and something is
/// [written], Queue (⏎: it waits for the agent's next chance) and Stop and
/// send (⌘⏎), pills on the card with their [words] where the row has room,
/// else round buttons with the same icons; Stop, round and solid red, while
/// a turn runs; else Send, round on the accent's fill, once something is
/// written. Those coming pop in once the box is there ([pop]).
class SendButtons extends StatelessWidget {
  const new(
    this.chat,
    this.daemon, {
    required this.written,
    required this.pop,
    required this.onSend,
    this.words = true,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final bool written;
  final bool pop;
  final bool words;

  /// Sends the box's message; `now` stops the turn first.
  final Future<void> Function({bool now}) onSend;

  /// The narrowest box whose pills keep their words beside the pickers.
  static const wordsFrom = 620.0;

  @override
  Widget build(BuildContext context) {
    final touch = TouchTargets.of(context);
    Widget act(String label, String key, IconData icon, VoidCallback run) {
      final tooltip = touch ? label : '$label ($key)';
      return words
          ? PillButton(
              label: label,
              icon: icon,
              tooltip: tooltip,
              onPressed: run,
            )
          : RoundButton(
              tooltip: tooltip,
              onPressed: run,
              glyph: (color) => Icon(icon, size: 16, color: color),
            );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: touch ? 0 : 6,
      children: [
        // Queue (after this turn) and Stop and send (stop it, and this goes
        // now): a phone's only way, the Mac's ⏎ and ⌘⏎ as buttons. One
        // coming pops in (Enter.pop).
        if (written && chat.busy) ...[
          Enter.pop(
            key: const ValueKey('queue'),
            play: pop,
            child: act('Queue', enterLabel, Icons.queue, onSend),
          ),
          if (chat.started != null)
            Enter.pop(
              key: const ValueKey('now'),
              play: pop,
              child: act(
                'Stop and send',
                cmdEnterLabel,
                Icons.fast_forward,
                () => onSend(now: true),
              ),
            ),
        ],
        if (chat.started != null)
          Enter.pop(
            key: const ValueKey('stop'),
            play: pop,
            child: RoundButton(
              kind: RoundKind.stop,
              tooltip: 'Stop (esc)',
              onPressed: () => stopTurn(context, chat, daemon),
              glyph: (color) =>
                  Icon(Icons.stop_rounded, size: 18, color: color),
            ),
          )
        else if (written && !chat.busy)
          Enter.pop(
            key: const ValueKey('send'),
            play: pop,
            child: RoundButton(
              kind: RoundKind.primary,
              tooltip: 'Send ($enterLabel)',
              onPressed: onSend,
              glyph: (color) =>
                  Icon(Icons.arrow_upward, size: 17, color: color),
            ),
          ),
      ],
    );
  }
}
