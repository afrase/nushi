import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_appearance.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme_files.dart';
import 'package:nushi/theme_preview.dart';
import 'package:nushi/widgets.dart' show tryOrShow;

/// Settings › Appearance's Theme (ADR 0086): Mode (System, Light, Dark)
/// first, then a card for each theme, the built-ins then the user's, each
/// a picture of Nushi in it in the set the app shows; a pick applies at
/// once, and the picked card, ringed and checked, is the one place it
/// shows. A user's card says what's wrong with its file and its pairs
/// under AA (a warning, never a refusal); a file that's no theme at all
/// says so under the cards. Then New from the current one and Show folder.
class ThemeGroup extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([colorTheme, themeFiles]),
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final look = t.brightness;
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
          const ModeRow(),
          Padding(padding: const EdgeInsets.all(12), child: _Grid(cards)),
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

/// A preview with a hairline where its edge meets the card (another
/// theme's window can be the card's own color), its corners rounded.
class _Framed extends StatelessWidget {
  const new(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => framed(
    border: NushiTheme.of(context).t.line,
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

  /// The shown set's own name, where its palette names it otherwise than
  /// the theme (Catppuccin's Mocha, Tokyo Night's Day); else null.
  String? get setName =>
      switch (look == Brightness.dark ? theme.darkName : theme.lightName) {
        final n? when n != theme.name => n,
        _ => null,
      };

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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            // A raised bit on the group's card (ADR 0111), no outline; the
            // picked one keeps its ring, as the focus does.
            color: look.pressed
                ? Color.alphaBlend(t.pressed, t.lifted)
                : look.hover
                ? Color.alphaBlend(t.hover, t.lifted)
                : t.lifted,
            border: Border.all(
              color: look.focus
                  ? t.focus
                  : picked
                  ? t.accentInk
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(NushiTheme.card),
          ),
          // The ring is always as wide, so it never moves what's inside.
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
    );
  }
}

/// A card's name, a check when it's the picked one; a user's says
/// "Yours" and its file, with Show in Finder.
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
                Text(
                  card.theme.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nushi.ui(
                    t.text,
                    weight: card.picked ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                // A set its palette names apart (Tokyo Night Day) says so.
                if (card.setName case final set?)
                  Text(
                    set,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nushi.ui(t.textMuted, size: 11.5),
                  ),
                if (card.file case final f?)
                  Text(
                    'Yours · $f',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nushi.ui(t.textMuted, size: 11.5),
                  ),
              ],
            ),
          ),
        ),
        if (card.picked)
          Icon(
            Icons.check_circle,
            key: const ValueKey('theme-check'),
            size: 15,
            color: t.accentInk,
          ),
        if (card.file case final f?)
          IconTap(
            Icons.folder_open_outlined,
            key: ValueKey('theme-reveal-$f'),
            tooltip: conventions.reveal,
            size: 15,
            onTap: () =>
                unawaited(tryOrShow(context, () => themeFiles.revealFile(f))),
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
          onPressed: () =>
              unawaited(tryOrShow(context, () => themeFiles.make(picked))),
        ),
        Button(
          label: 'Show folder',
          onPressed: () => unawaited(tryOrShow(context, themeFiles.reveal)),
        ),
      ],
    );
    const about = 'A JSON file each in the themes folder.';
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 520
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
