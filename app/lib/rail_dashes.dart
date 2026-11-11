import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/rail.dart' show RailEntry;
import 'package:nushi/theme/theme.dart';

// A rail's dashes (rail.dart): where they stand beside the text, how long
// each is, and the column of them the rail draws; its menu draws one beside
// each title.

/// The room between the dashes, and their thickness.
const _pitch = 8.0;
const _thick = 2.0;

/// How far right a dash stands, and how much shorter it is, for each level
/// of an outline's entry.
const _step = 3.0;
const _shorter = 2.0;

/// Where the rail's dashes stand and how long they are, given the room
/// beside the transcript's text ([margin], its left inset): as Claude's
/// (15 from the edge, 14 and 9 long), unless the margin is too narrow for
/// that and a gap of [gap] to the words; then nearer the edge, and if need
/// be shorter (the phone's, a narrow window's). A long dash nearer the
/// words reads as a dash opening the line beside it.
@immutable
class RailFit {
  const new _(this.margin, this.inset, this.long, this.short);

  factory of(double margin) {
    final inset = (margin - 14 - gap).clamp(3, 15).toDouble();
    final long = (margin - inset - gap).clamp(6, 14).toDouble();
    return RailFit._(margin, inset, long, (long * 9 / 14).roundToDouble());
  }

  /// As in a wide window: room enough.
  static const wide = RailFit._(40, 15, 14, 9);

  /// The room between a long dash and the words.
  static const gap = 8.0;

  final double margin;

  /// How far right of the transcript's left edge the dashes stand.
  final double inset;

  /// The current entry's dash, and the others'.
  final double long;
  final double short;

  /// An entry's dash, the current one's if [on].
  double dash({required bool on}) => on ? long : short;

  @override
  bool operator ==(Object other) =>
      other is RailFit &&
      other.margin == margin &&
      other.inset == inset &&
      other.long == long;

  @override
  int get hashCode => Object.hash(margin, inset, long);
}

/// The most dashes the rail draws: with more entries, those around the
/// current one, so it stays short (the menu lists them all).
const railMost = 12;

/// The rail's dashes, [current]'s long and bright; at most [railMost].
class RailDashes extends StatelessWidget {
  const new({
    required this.shown,
    required this.entries,
    required this.outline,
    required this.current,
    required this.fit,
    required this.look,
    required this.padding,
    super.key,
  });

  final bool shown;
  final List<RailEntry> entries;
  final bool outline;
  final int current;
  final RailFit fit;
  final ControlLook look;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final count = entries.length;
    final from = (current - railMost ~/ 2)
        .clamp(0, max(0, count - railMost))
        .toInt();
    return Container(
      padding: padding,
      foregroundDecoration: focusRing(t, look),
      child: Opacity(
        opacity: shown ? 1 : 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: _pitch - _thick,
          children: [
            for (var i = from; i < min(count, from + railMost); i++)
              RailDash(
                on: i == current,
                fit: fit,
                accent: outline,
                depth: outline ? entries[i].depth : 0,
              ),
          ],
        ),
      ),
    );
  }
}

/// One entry's dash: long and bright for the current one ([on]; the
/// accent's if [accent]), short and dim otherwise; between the two if
/// [bright] (its row under the pointer or the keys), as Claude's hovered
/// row has it. Other than the current one, a [depth] deeper stands
/// further right and is shorter.
class RailDash extends StatelessWidget {
  const new({
    required this.on,
    super.key,
    this.fit = RailFit.wide,
    this.bright = false,
    this.accent = false,
    this.depth = 0,
  });

  final bool on;
  final RailFit fit;
  final bool bright;
  final bool accent;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final deep = on ? 0 : depth;
    final dash = AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : Motion.quick,
      width: max(_thick * 2, fit.dash(on: on) - deep * _shorter),
      height: _thick,
      decoration: BoxDecoration(
        color: on
            ? (accent ? t.accentInk : t.text)
            : bright
            ? Color.lerp(t.faint, t.text, 0.5)
            : t.faint,
        borderRadius: BorderRadius.circular(NushiTheme.pill),
      ),
    );
    return deep == 0
        ? dash
        : Padding(
            padding: EdgeInsets.only(left: deep * _step),
            child: dash,
          );
  }
}
