import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme_files.dart';
import 'package:nushi/theme_strip.dart';

/// Settings › General's Theme (ADR 0086): a tile for each theme, the
/// built-ins then the user's, each its name and its dark and light key
/// colors; a pick applies at once. Under them what's wrong with a theme
/// file, a custom theme's pairs under AA (a warning, never a refusal), and
/// New theme from the current one and Show themes folder.
class ThemeGroup extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([colorTheme, themeFiles]),
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final picked = pickedTheme();
      final files = themeFiles.value;
      final custom = [
        for (final f in files)
          if (f.theme case final c?) (c, f.file),
      ];
      final lines = [
        for (final f in files)
          for (final n in f.notes.take(3)) (_Line.note, '${f.file}: $n'),
        for (final (c, _) in custom)
          for (final (set, tokens) in [('dark', c.dark), ('light', c.light)])
            if (contrastWarnings(tokens) case final w when w.isNotEmpty)
              (
                _Line.warning,
                '${c.name}, $set: ${w.first}'
                    '${w.length > 1 ? ' (and ${w.length - 1} more)' : ''}',
              ),
      ];
      return SettingsGroup(
        title: 'Theme',
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in builtInThemes)
                  ThemeTile(c, picked: c.id == picked.id),
                for (final (c, file) in custom)
                  ThemeTile(c, file: file, picked: c.id == picked.id),
              ],
            ),
          ),
          if (lines.isNotEmpty)
            Padding(
              key: const ValueKey('theme-notes'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  for (final (kind, line) in lines)
                    Text(
                      line,
                      style: theme.ui(
                        kind == _Line.warning ? t.needs : t.textMuted,
                        size: 12,
                      ),
                    ),
                ],
              ),
            ),
          _Actions(picked),
        ],
      );
    },
  );
}

enum _Line { note, warning }

/// What the user's themes are, then New from the current one and Show
/// folder: beside the words, or under them where the group is too narrow
/// for both.
class _Actions extends StatelessWidget {
  const new(this.picked);

  final ColorTheme picked;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final buttons = Wrap(
      spacing: NushiTheme.barGap,
      runSpacing: 8,
      children: [
        Button(
          label: 'New from ${picked.name}',
          tooltip: 'Writes a theme file with every color of this one',
          onPressed: () => unawaited(themeFiles.make(picked)),
        ),
        Button(
          label: 'Show folder',
          onPressed: () => unawaited(themeFiles.reveal()),
        ),
      ],
    );
    const about =
        'A JSON file each in the themes folder, read again when it changes.';
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 560
          ? SettingsRow('Your themes', description: about, control: buttons)
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your themes', style: theme.ui(t.text)),
                      Text(about, style: theme.ui(t.textMuted, size: 12)),
                    ],
                  ),
                  buttons,
                ],
              ),
            ),
    );
  }
}

/// A theme to pick: its name, [file] under it for one of the user's
/// ("Built in" for the others), its dark strip over its light one, ringed
/// in the accent when [picked].
class ThemeTile extends StatelessWidget {
  const new(this.theme, {required this.picked, super.key, this.file});

  final ColorTheme theme;
  final bool picked;
  final String? file;

  @override
  Widget build(BuildContext context) {
    final nushi = NushiTheme.of(context);
    final t = nushi.t;
    return Semantics(
      selected: picked,
      button: true,
      label: theme.name,
      child: Pressable(
        onTap: () => colorTheme.value = theme.id,
        builder: (context, look) => Container(
          width: 176,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: look.pressed
                ? Color.alphaBlend(t.pressed, t.fieldFill)
                : look.hover
                ? Color.alphaBlend(t.hover, t.fieldFill)
                : t.fieldFill,
            border: Border.all(
              color: picked || look.focus ? t.accentInk : t.fieldBorder,
              width: picked || look.focus ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(NushiTheme.card),
          ),
          // The border's width never moves what's inside.
          child: Padding(
            padding: EdgeInsets.all(picked || look.focus ? 0 : 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        theme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nushi.ui(t.text, weight: FontWeight.w500),
                      ),
                    ),
                    if (picked) Icon(Icons.check, size: 15, color: t.accentInk),
                  ],
                ),
                Text(
                  file ?? 'Built in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nushi.ui(t.textMuted, size: 11.5),
                ),
                ThemeStrip(theme.dark, outline: t.borderStrong),
                ThemeStrip(theme.light, outline: t.borderStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
