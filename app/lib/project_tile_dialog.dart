import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat_colors.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_images.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/tile_picture.dart';
import 'package:nushi/widgets.dart';

/// Change tile…, from a project's menu: an image of the user's own, an
/// emoji or one or two characters, and a color for [folder]'s tile, which
/// then shows them rather than the repository's icon ([projectTiles]).
/// [color] is the tile's place in the sidebar's colors while none is
/// chosen.
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
/// mark, the eight colors, and Choose image… (the system's panel: a PNG,
/// JPEG, GIF or WebP, checked as it's picked; one that can't be taken is
/// said in a line, and what was there stays), with Remove image once
/// there's one. Save keeps them, the image as a copy in Nushi's data
/// (`tile_images.dart`); Cancel keeps nothing, a picked image included.
/// Reset puts the tile back as it is by itself (the repository's icon,
/// else its initials).
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

  /// The stored image it keeps ('' once removed, or with none), and one
  /// picked here and not stored yet, which comes before it.
  late String _image = _before.image;
  PickedImage? _picked;
  int _picks = 0;
  String? _refused; // why the last file picked wasn't taken

  String get _pickedKey => 'picked:${widget.folder}:$_picks';

  @override
  void dispose() {
    forgetPicture(_pickedKey);
    _mark.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final file = await pickTileImage();
    if (file == null || !mounted) return;
    try {
      final picked = await readTileImage(file.path);
      if (!mounted) return;
      forgetPicture(_pickedKey);
      setState(() {
        _picks++;
        _picked = picked;
        _refused = null;
      });
    } on TileImageRefused catch (e) {
      if (mounted) setState(() => _refused = e.why);
    }
  }

  void _removeImage() => setState(() {
    _picked = null;
    _image = '';
    _refused = null;
  });

  TilePicture? get _picture => switch (_picked) {
    final p? => TilePicture.picked(_pickedKey, p.bytes),
    null => null,
  };

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

  TileLook get _look => TileLook(
    mark: tileMark(_mark.text),
    color: _color?.name ?? '',
    image: _image,
  );

  /// Keeps what's set: a picked image is copied into Nushi's data only
  /// now, and the one it replaces deleted ([setProjectTile]).
  void _save() {
    final look = _look;
    try {
      setProjectTile(widget.folder, switch (_picked) {
        final p? => TileLook(
          mark: look.mark,
          color: look.color,
          image: keepTileImage(p),
        ),
        null => look,
      });
    } on Object {
      setState(() => _refused = 'That image couldn’t be kept.');
      return;
    }
    Navigator.pop(context);
  }

  void _reset() {
    setProjectTile(widget.folder, const TileLook());
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
              picture: _picture,
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
                    onSubmitted: (_) => _save(),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Button(label: 'Choose image…', onPressed: _choose),
                    if (_picked != null || _image.isNotEmpty)
                      Button(
                        label: 'Remove image',
                        kind: ButtonKind.quiet,
                        onPressed: _removeImage,
                      ),
                  ],
                ),
                if (_refused case final why?)
                  Text(why, style: theme.ui(t.crashed, size: 12)),
                Text(
                  'For $name. Unset, it’s the repository’s icon or its '
                  'initials.',
                  style: theme.ui(t.textMuted, size: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      [
        Button(label: 'Reset', onPressed: _before.isEmpty ? null : _reset),
        Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        Button(label: 'Save', kind: ButtonKind.primary, onPressed: _save),
      ],
    );
  }
}
