import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/attached_files.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The + button's tooltip.
const plusTooltip = 'Add files, mention a file, or run a command';

/// ⌘U: Add files or photos, from the box, with the menu shut.
const attachKey = SingleActivator(LogicalKeyboardKey.keyU, meta: true);

/// The composer's + at the box's left and its menu, in the form of Claude's
/// app: Add files or photos (⌘U), Mention a file, Slash commands, each row a
/// line icon, its label and its key. The phone's has no keys. [locked]: the
/// box is read-only ([ChatState.rewinding]) and the + does nothing.
class PlusMenu extends StatelessWidget {
  const new({
    required this.chat,
    required this.api,
    required this.onAttach,
    required this.onMention,
    required this.onSlash,
    super.key,
    this.locked = false,
  });

  final ChatState chat;

  /// The daemon's API version: a phone's files need [attachApi].
  final int api;
  final VoidCallback onAttach;
  final VoidCallback onMention;
  final VoidCallback onSlash;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final touch = TouchTargets.of(context);
    // The phone's files go whole, which an older daemon doesn't take: then
    // only photos, and only for an agent that takes images.
    final photosOnly = sendWhole && api < attachApi;
    final attach = !photosOnly || chat.canImages;
    return Menu(
      above: true,
      filter: false,
      entries: [
        MenuEntry(
          photosOnly ? 'Add photos' : 'Add files or photos',
          line: LineIcon.paperclip,
          shortcut: touch ? '' : '⌘U',
          onPick: attach ? onAttach : null,
          tooltip: attach
              ? ''
              : '${chat.agentName} doesn’t take images in this chat, and '
                    'the Mac’s Nushi takes other files once it’s updated',
        ),
        MenuEntry('Mention a file', line: LineIcon.at, onPick: onMention),
        MenuEntry('Slash commands', line: LineIcon.slashBox, onPick: onSlash),
      ],
      builder: (context, open) => PlusButton(onPressed: locked ? () {} : open),
    );
  }
}

/// The + itself: a small filled square, as Claude's app has it, 28 high
/// like the box's other buttons (ADR 0072).
class PlusButton extends StatelessWidget {
  const new({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    // The fill is the square's own: a phone's taller touch target around
    // it stays clear.
    return Tap(
      tooltip: plusTooltip,
      onTap: onPressed,
      radius: NushiTheme.card,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.hover,
          borderRadius: BorderRadius.circular(NushiTheme.card),
        ),
        child: LineIcon.plus.view(size: 18, color: t.text),
      ),
    );
  }
}
