import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/theme/scrollbar.dart';
import 'package:nushi/theme/themes.dart';
import 'package:nushi/theme/tokens.dart';

export 'diff_colors.dart';
export 'scrollbar.dart';
export 'terminal_colors.dart';
export 'themes.dart';
export 'tokens.dart';

/// A box outlined in [border], filled with [fill], its corners rounded.
BoxDecoration box(
  Color border, {
  Color? fill,
  double radius = NushiTheme.card,
}) => BoxDecoration(
  color: fill,
  border: Border.all(color: border),
  borderRadius: BorderRadius.circular(radius),
);

/// A card on a pane (ADR 0111): a card's fill and corners, no outline.
BoxDecoration cardBox(Tokens t, {double radius = NushiTheme.card}) =>
    BoxDecoration(color: t.raised, borderRadius: BorderRadius.circular(radius));

/// What floats over the window (ADR 0111): a menu, a dialog, a popover,
/// a toast, a find bar. A card's fill, a hairline where its edge meets
/// what's under it and a soft shadow, never a strong outline; rounded by
/// [radius], a panel's unless given.
BoxDecoration floatBox(Tokens t, {double radius = NushiTheme.panel}) =>
    BoxDecoration(
      color: t.raised,
      border: Border.all(color: t.line),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: floatShadows(t),
    );

/// The shadow under what floats ([floatBox]): a wide soft one for its
/// height and a tight one that draws its edge.
List<BoxShadow> floatShadows(Tokens t) => [
  BoxShadow(color: t.floatShadow, blurRadius: 24, offset: const Offset(0, 8)),
  BoxShadow(color: t.floatShadow, blurRadius: 2, offset: const Offset(0, 1)),
];

/// A rounded box whose [child] is clipped to its corners, its border drawn
/// over the child: a fill, a bar or a hover inside never covers the
/// border's curve, as it does under a [box] border.
Widget framed({
  required Color border,
  required Widget child,
  Color? fill,
  double radius = NushiTheme.card,
  double? height,
  EdgeInsetsGeometry? margin,
}) => Container(
  height: height,
  margin: margin,
  clipBehavior: Clip.antiAlias,
  decoration: BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
  ),
  foregroundDecoration: box(border, radius: radius),
  child: child,
);

/// Carries the [Tokens] and the fonts to widgets: `NushiTheme.of(context)`.
/// Material's theme is derived from the tokens, never the other way round.
/// [dark] is the theme's dark set whatever the appearance, for what's dark
/// in both (the pill over a selection).
@immutable
class NushiTheme extends ThemeExtension<NushiTheme> {
  const new(this.t, {this._dark});

  final Tokens t;
  final Tokens? _dark;

  /// The theme's dark set: [t] when it's dark, Nushi's unless given.
  Tokens get dark =>
      _dark ?? (t.brightness == Brightness.dark ? t : Tokens.dark);

  static const uiFont = 'IBM Plex Sans';
  static const codeFont = 'JetBrains Mono';

  // Corner radii (ADR 0110): every rounded corner in the app is one of
  // these, or [inner] of one. A circle (a dot, an avatar), a scrollbar's
  // thumb and a drawn icon's own geometry are not corners and keep their
  // sizes.

  /// The smallest things: a key hint, a branch's name, a loading bar, a
  /// checkbox.
  static const tag = 4.0;

  /// Buttons, fields, icon buttons, a row's hover and selected fill, and
  /// the transcript's own parts: a tool call's row (a card's corners on one
  /// line make a lozenge), a code block, a diff, an image.
  static const control = 8.0;

  /// Cards and boxes ([box] and [framed] unless told otherwise).
  static const card = 12.0;

  /// A pane's corners (the main area, a details card), a menu's, a
  /// dialog's and a popover's, a message's bubble and the composer's box.
  static const panel = 14.0;

  /// Round ends, whatever the height: chips, badges, counts, round
  /// buttons, thin bars.
  static const pill = 999.0;

  /// The corners of a shape set [gap] inside one rounded by [outer] (its
  /// padding and border), so the two curves stay parallel: never more than
  /// the parent's.
  static double inner(double outer, double gap) => max(0, outer - gap);

  /// A menu's padding around its rows, which are rounded [inner] of it.
  static const menuPad = 5.0;

  // The window's shell (ADR 0111): the panes float on the window's own
  // background, this far in from its edges and from each other.
  static const windowPad = 8.0;
  static const paneGap = 8.0;

  // The Mac's chat area's spacing (ADR 0072). The phone keeps its own values,
  // decided where the two share a widget (TouchTargets).
  static const gutter = 24.0; // a side gutter
  static const barGap = 12.0; // between controls in a bar
  static const groupGap = 24.0; // between groups of them
  static const iconGap = 2.0; // between icon buttons, already padded

  static NushiTheme of(BuildContext context) =>
      Theme.of(context).extension<NushiTheme>()!;

  /// UI text: 13 for body, 12 for meta, 11.5 for small print.
  TextStyle ui(Color color, {double size = 13, FontWeight? weight}) =>
      TextStyle(
        fontFamily: uiFont,
        fontSize: size,
        fontWeight: weight,
        height: 1.4,
        color: color,
      );

  /// Code text, ligatures off, on a whole-pixel line height.
  TextStyle code(Color color, {double size = 13}) => TextStyle(
    fontFamily: codeFont,
    fontSize: size,
    height: (size * 1.45).roundToDouble() / size,
    color: color,
    fontFeatures: const [
      FontFeature.disable('liga'),
      FontFeature.disable('calt'),
    ],
  );

  // Equal when made of the same token sets, so a ThemeData built again from
  // the same theme, past forTheme's cache (the replies pill and the theme
  // previews make theirs on every build), equals the last one: an unequal
  // one rebuilds every reader of the theme below it, and under a theme
  // animation on each of its frames. The built-in sets are constants and a
  // theme file read again makes new ones, so an edited file still
  // re-themes.
  @override
  bool operator ==(Object other) =>
      other is NushiTheme &&
      identical(other.t, t) &&
      identical(other._dark, _dark);

  @override
  int get hashCode => Object.hash(identityHashCode(t), identityHashCode(_dark));

  @override
  NushiTheme copyWith({Tokens? t}) => NushiTheme(t ?? this.t, dark: _dark);

  // Light and dark switch at once.
  @override
  NushiTheme lerp(NushiTheme? other, double t) =>
      t < 0.5 || other == null ? this : other;

  /// Material's theme for [theme]'s set for [brightness], made once per
  /// theme: the app rebuilt with nothing changed (a theme file read again)
  /// gets the same one, so nothing below it rebuilds for it. ThemeData
  /// takes the platform it was made on, so that is part of the key too
  /// (it changes only in tests).
  static ThemeData forTheme(ColorTheme theme, Brightness brightness) =>
      (_made[theme] ??= {})[(brightness, defaultTargetPlatform)] ??= NushiTheme(
        theme.of(brightness),
        dark: theme.dark,
      ).toThemeData();

  static final _made = Expando<Map<(Brightness, TargetPlatform), ThemeData>>();

  /// How high Material draws what floats (a menu, a dialog, a toast), for
  /// its shadow: [floatShadows]' reach, about.
  static const floatElevation = 8.0;

  ThemeData toThemeData() {
    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: t.accentSoft,
      onPrimaryContainer: t.text,
      secondary: t.accent,
      onSecondary: t.onAccent,
      error: t.crashed,
      onError: t.onAccent,
      errorContainer: t.crashedSoft,
      onErrorContainer: t.crashed,
      surface: t.base,
      onSurface: t.text,
      onSurfaceVariant: t.textSecondary,
      surfaceContainerLowest: t.base,
      surfaceContainerLow: t.raised,
      surfaceContainer: t.raised,
      surfaceContainerHigh: t.raised,
      surfaceContainerHighest: t.selected,
      outline: t.fieldBorder,
      outlineVariant: t.line,
    );
    final typography = Typography.material2021();
    // Sizes merged with colors, scaled so body text is 13.
    final text = Typography.englishLike2021
        .merge(
          t.brightness == Brightness.dark ? typography.white : typography.black,
        )
        .apply(
          fontFamily: uiFont,
          fontSizeFactor: 13 / 14,
          bodyColor: t.text,
          displayColor: t.text,
        );
    return ThemeData(
      colorScheme: scheme,
      brightness: t.brightness,
      typography: typography,
      textTheme: text,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: t.base,
      dividerColor: t.line,
      dividerTheme: DividerThemeData(color: t.line, space: 1),
      focusColor: t.focus.withValues(alpha: 0.24),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: t.accent.withValues(alpha: 0.3),
        cursorColor: t.text,
      ),
      // Quiet: no ripples. What floats (a menu, a dialog, a tooltip, a
      // toast) is a card's fill with a hairline and a soft shadow, no
      // outline (ADR 0111).
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: t.hover,
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.raised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(floatElevation),
          shadowColor: WidgetStatePropertyAll(t.floatShadow),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(menuPad)),
          minimumSize: const WidgetStatePropertyAll(Size(200, 0)),
          side: WidgetStatePropertyAll(BorderSide(color: t.line)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(panel)),
            ),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(
          // Roomy enough to hit without aiming: the app's compact density
          // would take a menu row down to 20.
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.standard,
          // Inside the panel's round, by its padding.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inner(panel, menuPad)),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.raised,
        surfaceTintColor: Colors.transparent,
        elevation: floatElevation,
        shadowColor: t.floatShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(panel),
          side: BorderSide(color: t.line),
        ),
        titleTextStyle: ui(t.text, size: 15, weight: FontWeight.w600),
        contentTextStyle: ui(t.textSecondary),
      ),
      // An empty checkbox keeps an edge, as a field does, but a field's,
      // not Material's two heavy points of the text's color.
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(tag)),
        ),
        side: BorderSide(color: t.fieldBorderHover, width: 1.5),
      ),
      // A switch is its fill, never an outline (ADR 0111): off, a raised
      // bit's with a muted thumb; on, the accent's. Disabled it's
      // Material's own.
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        // Maps, which are equal when their colors are: a closure never is,
        // and an unequal theme rebuilds everything under it.
        trackColor: WidgetStateProperty<Color?>.fromMap({
          WidgetState.disabled: null,
          WidgetState.selected: t.accent,
          WidgetState.any: t.lifted,
        }),
        thumbColor: WidgetStateProperty<Color?>.fromMap({
          WidgetState.disabled: null,
          WidgetState.selected: t.onAccent,
          WidgetState.any: t.textMuted,
        }),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        isDense: true,
        contentPadding: const EdgeInsets.all(8),
        hintStyle: ui(t.textMuted),
        // A field keeps an edge, so it reads as one on any surface (ADR
        // 0111): the field's border, the focus ring's color once it has
        // the caret.
        // One that resolves by state, so a field that asks for no border
        // (the palette's, an inline edit's) still has none.
        border: WidgetStateInputBorder.resolveWith((states) {
          final focused = states.contains(WidgetState.focused);
          final color = states.contains(WidgetState.error)
              ? t.crashed
              : focused
              ? t.focus
              : states.contains(WidgetState.disabled)
              ? t.line
              : states.contains(WidgetState.hovered)
              ? t.fieldBorderHover
              : t.fieldBorder;
          return OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(control)),
            borderSide: BorderSide(color: color, width: focused ? 1.5 : 1),
          );
        }),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.lifted,
          borderRadius: BorderRadius.circular(control),
          boxShadow: [
            BoxShadow(
              color: t.floatShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        textStyle: ui(t.text, size: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
      snackBarTheme: SnackBarThemeData(
        // The lifted fill and a hairline, no shadow: Flutter clips a snack
        // bar to its own box, which cuts a shadow off hard at its sides.
        backgroundColor: t.lifted,
        contentTextStyle: ui(t.text),
        behavior: SnackBarBehavior.floating,
        // Its own size on the Mac, not the window's; a phone's fills the width.
        width: kIsWeb ? null : 420,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(card),
          side: BorderSide(color: t.line),
        ),
      ),
      extensions: [this],
    );
  }
}

/// Scrolling everywhere in the app: Apple's feel without the rubber band
/// (a list stops at its top and bottom, a chat's transcript too), and a
/// Mac's overlay scrollbar ([MacScrollbar]) on either axis.
class NativeScroll extends MaterialScrollBehavior {
  const new();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const EdgeStopScrollPhysics(parent: RangeMaintainingScrollPhysics());

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => MacScrollbar(
    controller: details.controller,
    ends: RoundedScroll.ends(context),
    child: child,
  );
}

/// [BouncingScrollPhysics] in all but the ends: a drag, a flick's glide and
/// carried momentum are Apple's, but the ends stop as
/// [ClampingScrollPhysics]'s do (a glide that reaches one stops there).
class EdgeStopScrollPhysics extends BouncingScrollPhysics {
  const new({super.parent});

  @override
  EdgeStopScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      EdgeStopScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) =>
      const ClampingScrollPhysics().applyBoundaryConditions(position, value);
}
