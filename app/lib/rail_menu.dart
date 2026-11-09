import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/rail.dart';
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';

// A rail's menu (rail.dart), as Claude's desktop app has it: each entry by
// its title ("Session start" and each pin, for the pins rail), each with its
// dash, the current one's title bright, the others dim.

/// A menu title's color, not the current one's: [Tokens.text] dimmed over
/// the menu's fill, as Claude's are (about half the contrast of the current
/// one's, whatever the theme; textSecondary is nearly text in some), but
/// no dimmer than reads on the fill.
Color railTitleDim(Tokens t) {
  for (var a = 0.6; ; a += 0.05) {
    final dim = Color.alphaBlend(t.text.withValues(alpha: a), t.raised);
    if (a >= 0.8 || contrast(dim, t.raised) >= 4) return dim;
  }
}

/// The rail's menu, over it: [entries] by title, each with its dash, the
/// current one's long and its title bright, the [lit] row filled.
class RailMenu extends StatelessWidget {
  const new({
    required this.entries,
    required this.current,
    required this.lit,
    required this.fit,
    required this.room,
    required this.onPick,
    super.key,
    this.outline = false,
  });

  final List<RailEntry> entries;
  final ValueListenable<int> current;
  final ValueNotifier<int?> lit;
  final RailFit fit;

  /// It's an outline's ([Rail.outline]): titles lined up, indented by
  /// their depth.
  final bool outline;

  /// How tall it can be: down to the window's bottom, from the rail.
  final double room;
  final void Function(int i) onPick;

  /// A row's height (a phone's taller), and the panel's padding.
  static const _row = 32.0;
  static const _pad = 5.0;

  /// How far right of the rail it opens: off the pane's edge.
  static const shift = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final phone = TouchTargets.of(context);
    final screen = MediaQuery.sizeOf(context);
    final row = phone ? TouchTargets.size : _row;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: min(220, screen.width - 16),
        maxWidth: min(340, screen.width - 16),
        maxHeight: max(row + 2 * _pad, room),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.raised,
            border: Border.all(color: t.borderStrong),
            borderRadius: BorderRadius.circular(NushiTheme.card),
            boxShadow: [
              BoxShadow(
                color: t.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: Listenable.merge([current, lit]),
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(_pad),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, e) in entries.indexed)
                      _MenuRow(
                        entry: e,
                        height: row,
                        // The dashes line up with the rail's under them.
                        inset: max(4, fit.inset - _pad - 1 - shift),
                        fit: fit,
                        outline: outline,
                        current: i == current.value,
                        lit: i == lit.value,
                        onHover: (on) {
                          if (on) {
                            lit.value = i;
                          } else if (lit.value == i) {
                            lit.value = null;
                          }
                        },
                        onTap: () => onPick(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How far an outline's title stands right for each level of its entry.
const _indent = 14.0;

/// One row of the rail's menu.
class _MenuRow extends StatelessWidget {
  const new({
    required this.entry,
    required this.height,
    required this.inset,
    required this.fit,
    required this.outline,
    required this.current,
    required this.lit,
    required this.onHover,
    required this.onTap,
  });

  final RailEntry entry;
  final double height;
  final double inset;
  final RailFit fit;
  final bool outline;
  final bool current;
  final bool lit;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final bright = current || lit;
    if (lit) {
      // A row the keys reach in a long menu scrolls into view; one under
      // the pointer shows already, and stays put.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        for (final policy in [
          ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        ]) {
          Scrollable.ensureVisible(context, alignmentPolicy: policy);
        }
      });
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          padding: EdgeInsets.only(left: inset, right: 12),
          decoration: BoxDecoration(
            color: lit ? t.hover : null,
            borderRadius: BorderRadius.circular(NushiTheme.control),
          ),
          child: Row(
            spacing: 10,
            children: [
              if (outline)
                // The longest dash's room, so the titles line up.
                SizedBox(
                  width: fit.long,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RailDash(
                      on: current,
                      fit: fit,
                      bright: bright,
                      accent: true,
                      depth: entry.depth,
                    ),
                  ),
                )
              else
                RailDash(on: current, fit: fit, bright: bright),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.only(left: entry.depth * _indent),
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(
                      bright ? t.text : railTitleDim(t),
                      size: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
