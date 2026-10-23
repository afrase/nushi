import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'widgets.dart';

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
      CancelTurnRequest(chatId: chat.id, takeBack: daemon.canTakeBack),
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
