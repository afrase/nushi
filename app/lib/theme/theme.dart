import 'package:flutter/material.dart';

import 'package:nushi/theme/scrollbar.dart';
import 'package:nushi/theme/tokens.dart';

export 'scrollbar.dart';
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
@immutable
class NushiTheme extends ThemeExtension<NushiTheme> {
  const new(this.t);

  final Tokens t;

  static const uiFont = 'IBM Plex Sans';
  static const codeFont = 'JetBrains Mono';

  // Corner radii: controls (buttons, fields) and cards.
  static const control = 4.0;
  static const card = 6.0;

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

  @override
  NushiTheme copyWith({Tokens? t}) => NushiTheme(t ?? this.t);

  // Light and dark switch at once.
  @override
  NushiTheme lerp(NushiTheme? other, double t) =>
      t < 0.5 || other == null ? this : other;

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
      outline: t.borderStrong,
      outlineVariant: t.borderSubtle,
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
      dividerColor: t.borderSubtle,
      dividerTheme: DividerThemeData(color: t.borderSubtle, space: 1),
      focusColor: t.focus.withValues(alpha: 0.24),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: t.accent.withValues(alpha: 0.3),
        cursorColor: t.text,
      ),
      // Quiet: no ripples, menus and dialogs with only a faint shadow.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: t.hover,
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.raised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(3),
          shadowColor: WidgetStatePropertyAll(t.shadow),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
          side: WidgetStatePropertyAll(BorderSide(color: t.borderStrong)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(card)),
            ),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(control)),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: t.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: t.borderStrong),
        ),
        titleTextStyle: ui(t.text, size: 15, weight: FontWeight.w600),
        contentTextStyle: ui(t.textSecondary),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        isDense: true,
        contentPadding: const EdgeInsets.all(8),
        hintStyle: ui(t.textMuted),
        border: const OutlineInputBorder(),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.raised,
          border: Border.all(color: t.borderStrong),
          borderRadius: BorderRadius.circular(control),
        ),
        textStyle: ui(t.text, size: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.raised,
        contentTextStyle: ui(t.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(card),
          side: BorderSide(color: t.borderStrong),
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
  ) => MacScrollbar(controller: details.controller, child: child);
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
