import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/theme/theme.dart';

/// How long a command's line in a stop runs, in characters, before it is
/// cut with an ellipsis.
const stopCommandLength = 60;

/// A stop of one of the agent's background tasks in one line, the same
/// queued and sent: "Stop: " and what it stops, a background command (the
/// call [call] in [chat] has a shell) by its first line cut to about 60
/// characters in code type, never the whole command; a subagent by its
/// type ([name]).
TextSpan stopLabel(
  NushiTheme theme,
  Color color,
  ChatState chat, {
  required String name,
  required String call,
}) {
  final shell = chat.items.any(
    (it) => it.id == call && it.hasBackgroundCommand(),
  );
  return TextSpan(
    children: [
      TextSpan(
        text: 'Stop: ',
        style: theme.ui(color, size: 12, weight: FontWeight.w600),
      ),
      if (shell)
        TextSpan(text: stopCommand(name), style: theme.code(color, size: 12))
      else
        TextSpan(
          text: name,
          style: theme.ui(color, size: 12, weight: FontWeight.w600),
        ),
    ],
  );
}

/// A command as a stop names it: its first line, cut to about
/// [stopCommandLength] characters; an ellipsis says there is more.
String stopCommand(String command) {
  final lines = command.trim().split('\n');
  final runes = lines.first.trimRight().runes.toList();
  if (runes.length > stopCommandLength) {
    return '${String.fromCharCodes(runes.take(stopCommandLength - 1))}…';
  }
  return lines.length > 1
      ? '${String.fromCharCodes(runes)} …'
      : String.fromCharCodes(runes);
}
