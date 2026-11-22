import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/settings.dart';
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

/// Stop's button in the prompt box: [child] in a small round area that
/// tints under the pointer, as it was before the redesign (the owner,
/// 2026-11-11: "the old one was fine").
Widget boxButton(String tooltip, VoidCallback onPressed, Widget child) => Tap(
  tooltip: tooltip,
  onTap: onPressed,
  radius: NushiTheme.pill,
  child: SizedBox.square(dimension: 28, child: Center(child: child)),
);

/// Stop: a filled square in a circle, like a media player's.
Widget stopIcon(Color color) => Container(
  width: 16,
  height: 16,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(color: color, width: 1.5),
  ),
  child: Container(width: 6, height: 6, color: color),
);

/// Enter in a box that sends (the composer, a reply, the reply dialog, a
/// subagent's box, a review comment; the keypad's Enter too), one
/// rule for all of them, which Settings › General's "Enter starts a new
/// line" ([enterStartsLine], ADR 0147) changes for all of them at once.
/// Off (at first): Enter sends, alone or with ⌘ (the usual "send" on a
/// Mac, as ⌘⏎ posts from GitHub's comment box); with ⇧, ⌥ or ⌃ it starts a
/// line. On: Enter starts a line, alone or with ⇧, ⌥ or ⌃, and sends only
/// with ⌘ held, as GitHub's comment box and Slack's "start a new line"
/// have it. Nushi writes that line itself ([startLine]) and keeps the key
/// from the field, so there is one way for all and never two lines: left
/// to macOS's text input, a Flutter field starts one for ⇧ and ⌥ but types
/// a space for ⌃ (seen in a release build). A phone's Return is Enter
/// without them (the browser's keydown): it sends there, whatever the
/// pref (the phone has no such setting). Where Control is the command key
/// (Linux), Ctrl+Enter is ⌘⏎.
bool isSendKey(KeyEvent e) =>
    _isEnter(e) && (enterLines ? cmdPressed() : !_lineModifier);

/// Whether [e] is Enter that starts a line ([isSendKey]): with ⇧, ⌥ or ⌃
/// (not the command key), or, with "Enter starts a new line" on, without
/// the command key.
bool isLineKey(KeyEvent e) => _isEnter(e) && !isSendKey(e);

/// Whether Enter, sending from the composer while a turn runs, stops the
/// turn and sends now rather than queueing: ⌘ held, or ⇧⌘ with "Enter
/// starts a new line" on, where ⌘⏎ alone queues (ADR 0147).
bool sendNowHeld() =>
    cmdPressed() && (!enterLines || HardwareKeyboard.instance.isShiftPressed);

/// Enter in a menu open over a box that sends (the spelling menu): plain
/// Enter (or ⌘⏎) picks, in both modes of [isSendKey]; with ⇧, ⌥ or ⌃ it
/// isn't the menu's.
bool isPickKey(KeyEvent e) => _isEnter(e) && !_lineModifier;

/// Whether "Enter starts a new line" applies: its pref ([enterStartsLine]),
/// never on the phone (the web build), whose Return sends.
bool get enterLines => !kIsWeb && enterStartsLine.value;

/// The key that sends, as the platform writes it ([isSendKey]): ⏎, or ⌘⏎
/// with "Enter starts a new line" on; what queues while a turn runs.
String get sendKeyLabel => enterLines ? cmdEnterLabel : enterLabel;

/// The key that stops the turn and sends now ([sendNowHeld]): ⌘⏎, or ⇧⌘⏎
/// with "Enter starts a new line" on.
String get sendNowKeyLabel => enterLines
    ? keyLabel(const Cmd(LogicalKeyboardKey.enter, shift: true))
    : cmdEnterLabel;

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
/// keys ([isSendKey]): the send key runs [onEnter], a line key starts a
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

/// The end of the box's row (ADR 0111): while a turn runs and something is
/// [written], Queue (⏎, or ⌘⏎ with "Enter starts a new line" on: it waits
/// for the agent's next chance) and Stop and send (⌘⏎, or ⇧⌘⏎;
/// [sendKeyLabel], [sendNowKeyLabel]), pills on the card with their
/// [words] where the row has room, else round buttons with the same icons;
/// Stop, the square in a circle it always was ([stopIcon]), while a turn
/// runs; else Send, round on the accent's fill, once something is written.
/// Those coming pop in once the box is there ([pop]). In command mode
/// ([run], ADR 0148) Run takes Send's place, Queue's and Stop and send's
/// while a turn runs, Stop staying at the end.
class SendButtons extends StatelessWidget {
  const new(
    this.chat,
    this.daemon, {
    required this.written,
    required this.pop,
    required this.onSend,
    this.words = true,
    this.run,
    super.key,
  });

  /// The box's Run, in command mode; null otherwise.
  final Widget? run;

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
      final tooltip = touch ? label : withKey(label, key);
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
        if (run case final run?)
          Enter.pop(key: const ValueKey('run'), play: pop, child: run)
        else if (written && chat.busy) ...[
          Enter.pop(
            key: const ValueKey('queue'),
            play: pop,
            child: act('Queue', sendKeyLabel, Icons.queue, onSend),
          ),
          if (chat.started != null)
            Enter.pop(
              key: const ValueKey('now'),
              play: pop,
              child: act(
                'Stop and send',
                sendNowKeyLabel,
                Icons.fast_forward,
                () => onSend(now: true),
              ),
            ),
        ],
        if (chat.started != null)
          Enter.pop(
            key: const ValueKey('stop'),
            play: pop,
            child: boxButton(
              withKey('Stop', 'Esc'),
              () => stopTurn(context, chat, daemon),
              stopIcon(NushiTheme.of(context).t.textSecondary),
            ),
          )
        else if (written && !chat.busy && run == null)
          Enter.pop(
            key: const ValueKey('send'),
            play: pop,
            child: RoundButton(
              kind: RoundKind.primary,
              tooltip: withKey('Send', sendKeyLabel),
              onPressed: onSend,
              glyph: (color) =>
                  Icon(Icons.arrow_upward, size: 17, color: color),
            ),
          ),
      ],
    );
  }
}
