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

  /// Its mark: a swatch, a dot, a row's bar ([ColorBar]).
  Color ink(Tokens t) => t.avatars[index];
}

/// A chat's color on its row: a bar at the row's left edge, over [child]
/// and taking none of its width, so nothing moves when a color is set. A
/// mark, never a fill: a wash was too faint to see on the dark theme, and a
/// blue one read as the open chat's, which is the only row with a fill.
/// [width] is 3 on the Mac's sidebar, 4 on the phone's list; [inset] keeps
/// it off the row's top and bottom (and its rounded corners).
class ColorBar extends StatelessWidget {
  const new({
    required this.color,
    required this.child,
    super.key,
    this.width = 3,
    this.inset = 4,
  });

  /// The chat's color, or none, which shows [child] alone.
  final ChatColor? color;
  final Widget child;
  final double width;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final c = color;
    if (c == null) return child;
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: inset,
          bottom: inset,
          width: width,
          child: IgnorePointer(
            child: DecoratedBox(
              key: const Key('color bar'),
              decoration: BoxDecoration(
                color: c.ink(NushiTheme.of(context).t),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
