import 'package:flutter/material.dart';

import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// The app's one look for tabs (ADR 0071): plain text, the one showing in the
// primary color with a line under it, no box and no tint. The preview pane's
// file tabs (`preview_tabs.dart`) are drawn from these pieces too.

/// The color of a tab's text: the primary text on the one [showing], the
/// others muted, a step up under the pointer.
Color tabText(Tokens t, {required bool showing, required bool hover}) => showing
    ? t.text
    : hover
    ? t.textSecondary
    : t.textMuted;

/// A tab's [child], with a line along its bottom edge while [showing].
class TabFace extends StatelessWidget {
  const new({required this.showing, required this.child, super.key});

  final bool showing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      child,
      if (showing)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 2,
          child: ColoredBox(color: NushiTheme.of(context).t.textMuted),
        ),
    ],
  );
}

/// One of a few views of the same thing (`Chat | Changes`), as labels. It
/// measures what [Segmented] measures for the same labels, so a row built
/// around that width keeps it (the chat header's fold, ADR 0071). A value a
/// form saves or sends stays a [Segmented]: it isn't a place to go.
class PlainTabs<T> extends StatelessWidget {
  const new({
    required this.value,
    required this.tabs,
    required this.onChanged,
    super.key,
    this.tooltip,
    this.fill = false,
  });

  final T value;
  final List<(T, String)> tabs;
  final ValueChanged<T> onChanged;
  final String Function(T)? tooltip; // a tab's, such as its key

  /// Takes the height of its row, so the line lies on the row's bottom
  /// border as the file tabs' does. Off the pill's height is kept.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: fill
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.center,
        children: [
          for (final (v, text) in tabs)
            Semantics(
              selected: v == value,
              child: Pressable(
                onTap: () => onChanged(v),
                tooltip: tooltip?.call(v) ?? '',
                builder: (context, look) => Container(
                  foregroundDecoration: focusRing(t, look),
                  child: TabFace(
                    showing: v == value,
                    child: Container(
                      alignment: fill ? Alignment.center : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        text,
                        style: theme.ui(
                          tabText(t, showing: v == value, hover: look.hover),
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return fill ? SizedBox(height: double.infinity, child: row) : row;
  }
}
