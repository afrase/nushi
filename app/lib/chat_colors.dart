import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

/// A chat's color, set from its menu: with many chats the names blend
/// together and often no longer match the work. Its [name] is what the daemon
/// keeps (`Chat.color`, checked against the same eight there, in `chats`'
/// `chatColors`), so it stays when the theme changes and must never be
/// renamed; its position is its place in [Tokens.avatars].
enum ChatColor {
  blue('Blue'),
  teal('Teal'),
  violet('Violet'),
  amber('Amber'),
  rust('Rust'),
  magenta('Magenta'),
  slate('Slate'),
  green('Green');

  new(this.label);

  /// What a swatch's tooltip calls it.
  final String label;

  /// The color called [name]. Names come from the API, so anything else is
  /// null, which shows as no color.
  static ChatColor? named(String name) => values.asNameMap()[name];

  /// Its mark: a swatch, a row's or a header's chip ([ColorChip]).
  Color ink(Tokens t) => t.avatars[index];
}

/// A chat's color as a mark: a small filled lozenge in it, at the end of
/// the chat's row in the sidebar and on the phone's list, and before its
/// title in the header while the sidebar is hidden. A mark, never a fill:
/// a wash was too faint to see on the dark theme, and a blue one read as
/// the open chat's. And never a stripe down the row's side (ADR 0111),
/// which it was until then. Round ends, wider than high, so it reads apart
/// from the round state dots beside it.
class ColorChip extends StatelessWidget {
  const new(this.color, {super.key, this.named = false});

  final ChatColor color;

  /// Whether its tooltip names the color (the header's; a row has its
  /// chat's menu for that).
  final bool named;

  static const width = 12.0;
  static const height = 6.0;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      key: const Key('chat color'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.ink(NushiTheme.of(context).t),
        borderRadius: BorderRadius.circular(NushiTheme.pill),
      ),
    );
    return named ? Tooltip(message: color.label, child: chip) : chip;
  }
}

/// Gives [chat] [color], or none. It shows at once; if the daemon refuses, it
/// goes back as it was.
Future<void> setChatColor(Daemon d, ChatState chat, ChatColor? color) async {
  final before = chat.color;
  chat.color = color;
  try {
    await d.client.setChatColor(
      SetChatColorRequest(chatId: chat.id, color: color?.name ?? ''),
    );
  } on Object {
    chat.color = before;
    rethrow;
  }
}

/// The nine swatches of a chat's menu: No color, a hollow ring, and the
/// eight, its current one ringed. [onPick] has what was picked.
class ChatColorPicker extends StatelessWidget {
  const new(this.chat, {required this.onPick, super.key});

  final ChatState chat;
  final ValueChanged<ChatColor?> onPick;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Swatch(
          color: null,
          tooltip: 'No color',
          selected: chat.color == null,
          onTap: () => onPick(null),
        ),
        for (final c in ChatColor.values)
          Swatch(
            color: c.ink(t),
            tooltip: c.label,
            selected: chat.color == c,
            onTap: () => onPick(c),
          ),
      ],
    );
  }
}
