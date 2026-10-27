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

/// Whether [e] is Enter without Shift, which sends from the composer and a
/// reply; Shift-Enter is left to the (multi-line) field, which starts a
/// line. A phone's Return is Enter without Shift (the browser's keydown):
/// it sends there too.
bool isSendKey(KeyEvent e) =>
    e is! KeyUpEvent &&
    e.logicalKey == LogicalKeyboardKey.enter &&
    !HardwareKeyboard.instance.isShiftPressed;

/// [child], a multi-line text field, with the composer's keys: Enter runs
/// [onEnter], Shift-Enter starts a line ([isSendKey]).
class EnterSends extends StatelessWidget {
  const new({required this.onEnter, required this.child, super.key});

  final VoidCallback onEnter;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    skipTraversal: true,
    onKeyEvent: (_, e) {
      if (!isSendKey(e)) return KeyEventResult.ignored;
      onEnter();
      return KeyEventResult.handled;
    },
    child: child,
  );
}
