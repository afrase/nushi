import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme_files.dart';
import 'package:nushi/theme_preview.dart';

/// Settings › Appearance's Theme (ADR 0086): the picked theme large, its
/// dark and light sets side by side, then a card for each theme, the
/// built-ins then the user's, each a picture of Nushi in it; a pick applies
/// at once. The cards show the set the app shows unless Dark or Light over
/// them says otherwise (a look, not the appearance). A user's card says
/// what's wrong with its file and its pairs under AA (a warning, never a
/// refusal); a file that's no theme at all says so under the cards. Then
/// New from the current one and Show folder.
class ThemeGroup extends StatefulWidget {
  const new({super.key});

  @override
  State<ThemeGroup> createState() => _ThemeGroupState();
}

class _ThemeGroupState extends State<ThemeGroup> {
  /// The set the cards show, when it isn't the app's.
  Brightness? _look;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([colorTheme, themeFiles]),
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final look = _look ?? t.brightness;
      final picked = pickedTheme();
      final files = themeFiles.value;
      final cards = [
        for (final c in builtInThemes)
          ThemeCard(c, picked: c.id == picked.id, look: look),
        for (final f in files)
          if (f.theme case final c?)
            ThemeCard(
              c,
              picked: c.id == picked.id,
              look: look,
              file: f.file,
              warnings: [
                ...f.notes.take(3),
                for (final (set, tokens) in [
                  ('Dark', c.dark),
                  ('Light', c.light),
                ])
                  if (contrastWarnings(tokens) case final w when w.isNotEmpty)
                    _warning(set, w),
              ],
            ),
      ];
      final unread = [
        for (final f in files)
          if (f.theme == null)
            for (final n in f.notes.take(3)) '${f.file}: $n',
      ];
      return SettingsGroup(
        title: 'Theme',
        children: [
          _Picked(picked),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Themes',
                        style: theme.ui(t.textSecondary, size: 12),
                      ),
                    ),
                    PlainTabs(
                      key: const ValueKey('theme-look'),
                      value: look,
                      tabs: const [
                        (Brightness.dark, 'Dark'),
                        (Brightness.light, 'Light'),
                      ],
                      tooltip: (_) => 'Previews only; Appearance stays',
                      onChanged: (b) =>
                          setState(() => _look = b == t.brightness ? null : b),
                    ),
                  ],
                ),
                _Grid(cards),
              ],
            ),
          ),
          if (unread.isNotEmpty)
            Padding(
              key: const ValueKey('theme-notes'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  for (final line in unread)
                    Text(line, style: theme.ui(t.textMuted, size: 12)),
                ],
              ),
            ),
          _Actions(picked),
        ],
      );
    },
  );
}

/// The first of a set's contrast warnings [w] on a card, and how many more.
String _warning(String set, List<String> w) =>
    '$set: ${w.first}${w.length > 1 ? ' (and ${w.length - 1} more)' : ''}';

/// The picked theme, large: its name, then its dark and its light set
/// side by side, or one over the other where the group is narrow.
class _Picked extends StatelessWidget {
  const new(this.picked);

  final ColorTheme picked;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Widget set(String name, Tokens tokens) => Column(
      key: ValueKey('picked-${name.toLowerCase()}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 5,
      children: [
        _Framed(ThemePreview(tokens, dark: picked.dark)),
        Text(name, style: theme.ui(t.textMuted, size: 12)),
      ],
    );
    return Padding(
      key: const ValueKey('theme-picked'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            picked.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.text, size: 15, weight: FontWeight.w600),
          ),
          LayoutBuilder(
            builder: (context, box) {
              final dark = set('Dark', picked.dark);
              final light = set('Light', picked.light);
              return box.maxWidth >= 480
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        Expanded(child: dark),
                        Expanded(child: light),
                      ],
                    )
                  : Column(spacing: 10, children: [dark, light]);
            },
          ),
        ],
      ),
    );
  }
}

/// A preview in a hairline frame, its corners rounded.
class _Framed extends StatelessWidget {
  const new(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => framed(
    border: NushiTheme.of(context).t.borderStrong,
    // Inside its card's padding (7) and border.
    radius: NushiTheme.inner(NushiTheme.card, 8),
    child: child,
  );
}

/// The cards, as many across as fit at [_least] wide (three at most), each
/// row as tall as its tallest.
class _Grid extends StatelessWidget {
  const new(this.cards);

  final List<Widget> cards;

  static const _least = 170.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final across = ((box.maxWidth + _gap) ~/ (_least + _gap)).clamp(1, 3);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _gap,
        children: [
          for (var i = 0; i < cards.length; i += across)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _gap,
                children: [
                  for (var j = i; j < i + across; j++)
                    Expanded(
                      child: j < cards.length ? cards[j] : const SizedBox(),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// A theme to pick: a picture of Nushi in its [look] set, its name, and
/// "Built in" or, for one of the user's, "Yours" and its [file] with Show
/// in Finder, then its [warnings]; ringed in the accent when [picked].
class ThemeCard extends StatelessWidget {
  const new(
    this.theme, {
    required this.picked,
    required this.look,
    super.key,
    this.file,
    this.warnings = const [],
  });

  final ColorTheme theme;
  final bool picked;
  final Brightness look;
  final String? file;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final nushi = NushiTheme.of(context);
    final t = nushi.t;
    final ring = picked ? t.accentInk : t.fieldBorder;
    return Semantics(
      selected: picked,
      button: true,
      label: theme.name,
      child: Pressable(
        onTap: () => colorTheme.value = theme.id,
        builder: (context, look) => Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: look.pressed
                ? Color.alphaBlend(t.pressed, t.fieldFill)
                : look.hover
                ? Color.alphaBlend(t.hover, t.fieldFill)
                : t.fieldFill,
            border: Border.all(
              color: look.focus ? t.focus : ring,
              width: picked || look.focus ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(NushiTheme.card),
          ),
          // The border's width never moves what's inside.
          child: Padding(
            padding: EdgeInsets.all(picked || look.focus ? 0 : 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Framed(ThemePreview(theme.of(this.look), dark: theme.dark)),
                const SizedBox(height: 6),
                _Name(this),
                for (final w in warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      w,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: nushi.ui(t.needs, size: 11.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A card's name and where it's from; the user's, Show in Finder.
class _Name extends StatelessWidget {
  const new(this.card);

  final ThemeCard card;

  @override
  Widget build(BuildContext context) {
    final nushi = NushiTheme.of(context);
    final t = nushi.t;
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 4,
                  children: [
                    Flexible(
                      child: Text(
                        card.theme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nushi.ui(t.text, weight: FontWeight.w500),
                      ),
                    ),
                    if (card.picked)
                      Icon(Icons.check, size: 15, color: t.accentInk),
                  ],
                ),
                Text(
                  card.file == null ? 'Built in' : 'Yours · ${card.file}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nushi.ui(t.textMuted, size: 11.5),
                ),
              ],
            ),
          ),
        ),
        if (card.file case final f?)
          IconTap(
            Icons.folder_open_outlined,
            key: ValueKey('theme-reveal-$f'),
            tooltip: conventions.reveal,
            size: 15,
            onTap: () => unawaited(themeFiles.revealFile(f)),
          ),
      ],
    );
  }
}

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
