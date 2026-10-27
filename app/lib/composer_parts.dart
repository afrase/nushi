import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/widgets.dart';

/// Stops the chat's running turn. If the agent hasn't answered the last
/// message yet, the daemon takes it back too, for the composer.
Future<void> stopTurn(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async {
  if (chat.started == null || chat.stopping) return;
  chat.stopping = true;
  await tryOrShow(context, () async {
    final r = await daemon.client.cancelTurn(
      CancelTurnRequest(chatId: chat.id, takeBack: true),
    );
    if (r.hasMessage()) chat.takeBack.value = r.message;
  });
  chat.stopping = false;
}

/// A small round icon button inside the prompt box.
Widget boxButton(String tooltip, VoidCallback onPressed, Widget child) => Tap(
  tooltip: tooltip,
  onTap: onPressed,
  radius: 14,
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

/// Enter in a box that sends (the composer, a reply, the reply dialog), one
/// rule for all of them: Enter sends, alone or with ⌘ (the usual "send" on a
/// Mac, as ⌘⏎ posts from GitHub's comment box); with ⇧, ⌥ or ⌃ it starts a
/// line. Nushi writes that line itself ([startLine]) and keeps the key from
/// the field, so there is one way for all and never two lines: left to
/// macOS's text input, a Flutter field starts one for ⇧ and ⌥ but types a
/// space for ⌃ (a release build, step 346). A phone's Return is Enter
/// without them (the browser's keydown): it sends there too.
bool isSendKey(KeyEvent e) => _isEnter(e) && !_lineModifier;

/// Whether [e] is Enter with ⇧, ⌥ or ⌃, which starts a line ([isSendKey]).
bool isLineKey(KeyEvent e) => _isEnter(e) && _lineModifier;

bool _isEnter(KeyEvent e) =>
    e is! KeyUpEvent && e.logicalKey == LogicalKeyboardKey.enter;

bool get _lineModifier {
  final k = HardwareKeyboard.instance;
  return k.isShiftPressed || k.isAltPressed || k.isControlPressed;
}

/// Puts a line break in [text] at its selection, in place of what's
/// selected, the cursor after it.
void startLine(TextEditingController text) {
  final v = text.value;
  final s = v.selection.isValid
      ? v.selection
      : TextSelection.collapsed(offset: v.text.length);
  text.value = TextEditingValue(
    text: v.text.replaceRange(s.start, s.end, '\n'),
    selection: TextSelection.collapsed(offset: s.start + 1),
  );
}

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
