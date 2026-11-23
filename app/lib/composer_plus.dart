import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/widgets.dart';

/// The + button's tooltip.
const plusTooltip = 'Add files, mention a file, or run a command';

/// ⌘U: Add files or photos, from the box, with the menu shut; once a
/// press, not again as the key repeats.
const attachKey = Cmd(LogicalKeyboardKey.keyU, includeRepeats: false);

/// The composer's + at the box's left and its menu, in the form of Claude's
/// app: Add files or photos (⌘U), Mention a file, Slash commands, each row a
/// line icon, its label and its key. The phone's has no keys. [locked]: the
/// box is read-only ([ChatState.rewinding]) and the + does nothing.
class PlusMenu extends StatelessWidget {
  const new({
    required this.chat,
    required this.onAttach,
    required this.onMention,
    required this.onSlash,
    required this.box,
    super.key,
    this.locked = false,
  });

  final ChatState chat;

  final VoidCallback onAttach;
  final VoidCallback onMention;
  final VoidCallback onSlash;
  final bool locked;

  /// The box the + sits in: the menu opens over it, as Claude's does.
  final GlobalKey box;

  @override
  Widget build(BuildContext context) {
    final touch = TouchTargets.of(context);
    return Menu(
      above: true,
      aboveOf: box,
      largeIcons: true,
      filter: false,
      entries: [
        MenuEntry(
          'Add files or photos',
          line: LineIcon.paperclip,
          shortcut: touch ? '' : keyLabel(attachKey),
          onPick: onAttach,
          // The phone's picker is the browser's, which opens only from
          // inside the tap.
          inTap: true,
        ),
        MenuEntry('Mention a file', line: LineIcon.at, onPick: onMention),
        MenuEntry('Slash commands', line: LineIcon.slashBox, onPick: onSlash),
      ],
      builder: (context, open) => PlusButton(onPressed: locked ? () {} : open),
    );
  }
}

/// The + itself: a round button on the card's lifted fill, as the row's
/// other buttons (ADR 0111).
class PlusButton extends StatelessWidget {
  const new({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => RoundButton(
    tooltip: plusTooltip,
    onPressed: onPressed,
    glyph: (color) => LineIcon.plus.view(size: 18, color: color),
  );
}
