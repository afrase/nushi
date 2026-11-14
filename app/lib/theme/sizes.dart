import 'package:flutter/widgets.dart';

import 'package:nushi/theme/theme.dart';

/// How big a control is, chosen by where it sits, never by the call
/// (ADR 0122): a button, a menu field, a segmented control and a field
/// read their size from the nearest [ControlScale], [regular] without one.
enum ControlSize {
  /// In a dense place, where a control shares a line with text: a row of a
  /// list, a table or a menu, a widget of the details panel, a one-line
  /// toast, a bar while it's narrow. The old size of every control.
  compact(height: 26, pad: 10, text: 13, icon: 14, minWidth: 0),

  /// Everywhere else: a bar, a card, a settings row, a form's fields.
  regular(height: 30, pad: 12, text: 13, icon: 14, minWidth: 0),

  /// A dialog's actions and a view's main call to action (an empty view's
  /// New chat): a step up in height and type, and wide enough that a
  /// short label (OK, Add) still reads as a button.
  large(height: 34, pad: 16, text: 14, icon: 15, minWidth: 80);

  new({
    required this.height,
    required this.pad,
    required this.text,
    required this.icon,
    required this.minWidth,
  });

  /// The control's height.
  final double height;

  /// The room at a button's ends, before its icon or label.
  final double pad;

  /// The label's size, in points.
  final double text;

  /// A leading icon's size.
  final double icon;

  /// A button's narrowest.
  final double minWidth;

  /// Its corners: [NushiTheme.control] at the compact height, the same
  /// share of the height at the others, so every size has one shape and a
  /// rounder theme rounds them all (ADR 0110).
  double get radius => radiusFor(height);

  /// The corners of a control [height] high by the same rule, for one
  /// that keeps its own height (`WideButton`'s 38).
  static double radiusFor(double height) =>
      NushiTheme.control * height / compact.height;

  /// The size the controls under [context] take: the nearest
  /// [ControlScale]'s, else [regular].
  static ControlSize of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ControlScale>()?.size ??
      regular;
}

/// Sets the [ControlSize] of the controls below it: a dense list says
/// [ControlSize.compact], a dialog's actions [ControlSize.large].
class ControlScale extends InheritedWidget {
  const new({required this.size, required super.child, super.key});

  /// Compact controls below.
  const new compact({required super.child, super.key})
    : size = ControlSize.compact;

  /// Large controls below.
  const new large({required super.child, super.key}) : size = ControlSize.large;

  final ControlSize size;

  @override
  bool updateShouldNotify(ControlScale oldWidget) => oldWidget.size != size;
}
