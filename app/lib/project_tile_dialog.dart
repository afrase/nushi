import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat_colors.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/widgets.dart';

/// Change tile…, from a project's menu: an emoji or one or two characters
/// and a color for [folder]'s tile, which then shows them rather than the
/// repository's icon ([projectTiles]). [color] is the tile's place in the
/// sidebar's colors while none is chosen.
Future<void> changeTile(
  BuildContext context,
  Daemon daemon,
  String folder, {
  required int color,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      ChangeTileDialog(daemon: daemon, folder: folder, color: color),
);

/// The dialog of [changeTile]: the tile as it will be, a field for its
/// mark and the eight colors. Save keeps them; Reset puts the tile back
/// as it is by itself (the repository's icon, else its initials).
class ChangeTileDialog extends StatefulWidget {
  const new({
    required this.daemon,
    required this.folder,
    required this.color,
    super.key,
  });

  final Daemon daemon;
  final String folder;
  final int color;

  @override
  State<ChangeTileDialog> createState() => _ChangeTileDialogState();
}

class _ChangeTileDialogState extends State<ChangeTileDialog> {
  late final TileLook _before =
      projectTiles.value[widget.folder] ?? const TileLook();
  late final _mark = TextEditingController(text: _before.mark);
  late ChatColor? _color = ChatColor.named(_before.color);

  @override
  void dispose() {
    _mark.dispose();
    super.dispose();
  }

  /// As many characters as a tile shows, an emoji one. What's entered
  /// into a full field takes the place of what was there (an emoji from a
  /// picker over the two letters), where refusing it looked like a field
  /// that takes no emoji.
  static final _lettersOnly = RegExp(r'^[\p{L}\p{N}\s]*$', unicode: true);

  static TextEditingValue _fit(TextEditingValue old, TextEditingValue now) {
    if (now.text.trim().characters.length <= 2) return now;
    final (from, to) = (old.selection.start, now.selection.end);
    final entered = from >= 0 && to > from && to <= now.text.length
        ? now.text.substring(from, to)
        : now.text;
    // A third letter is still refused: typing on doesn't wipe the two.
    if (_lettersOnly.hasMatch(entered.trim())) return old;
    final kept = tileMark(entered);
    return TextEditingValue(
      text: kept,
      selection: TextSelection.collapsed(offset: kept.length),
    );
  }

  TileLook get _look =>
      TileLook(mark: tileMark(_mark.text), color: _color?.name ?? '');

  void _save(TileLook look) {
    setProjectTile(widget.folder, look);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final name = folderParts(widget.folder).$1;
    final look = _look;
    return nushiDialog(
      'Change tile',
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          // As it will be: with nothing set, the tile as it is by itself.
          ListenableBuilder(
            listenable: widget.daemon.projectIcons,
            builder: (context, _) => ProjectTile(
              key: const Key('tile preview'),
              name: name,
              color: widget.color,
              look: look,
              icon: widget.daemon.projectIcons.of(widget.folder),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _mark,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      hintText: 'Emoji or two letters',
                    ),
                    inputFormatters: const [
                      TextInputFormatter.withFunction(_fit),
                    ],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(_look),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Swatch(
                      color: null,
                      tooltip: 'No color',
                      selected: _color == null,
                      onTap: () => setState(() => _color = null),
                    ),
                    for (final c in ChatColor.values)
                      Swatch(
                        color: c.ink(t),
                        tooltip: c.label,
                        selected: _color == c,
                        onTap: () => setState(() => _color = c),
                      ),
                  ],
                ),
                Text(
                  'For $name. With neither, the tile is the '
                  'repository’s icon, or its initials.',
                  style: theme.ui(t.textMuted, size: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      [
        Button(
          label: 'Reset',
          onPressed: _before.isEmpty ? null : () => _save(const TileLook()),
        ),
        Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        Button(
          label: 'Save',
          kind: ButtonKind.primary,
          onPressed: () => _save(_look),
        ),
      ],
    );
  }
}
