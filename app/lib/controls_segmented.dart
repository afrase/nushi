part of 'controls.dart';

/// One of a few, as a filled track with the picked segment raised on it
/// (ADR 0111): the chat header's Chat, Changes and Pull request ([roomy],
/// a header's size), and a value a form saves or sends (a server's scope,
/// a review's verdict). Other views of the same thing are still
/// `PlainTabs` (ADR 0071). The track is a card's fill, so on a card or a
/// dialog ([onCard]) it's a step up from that. A segment takes the
/// keyboard's focus; Enter and Space pick it. Its width doesn't change as
/// it's picked, though its label turns semibold.
class Segmented<T> extends StatelessWidget {
  const new({
    required this.value,
    required this.segments,
    required this.onChanged,
    super.key,
    this.roomy = false,
    this.onCard = false,
    this.tooltip,
    this.badges = const {},
  });

  final T value;
  final List<(T, String)> segments;
  final ValueChanged<T> onChanged;
  final bool roomy;
  final bool onCard;
  final String Function(T)? tooltip; // a segment's, such as its key

  /// A count after a segment's label (Changes' unsent comments), as a
  /// small pill in the accent.
  final Map<T, String> badges;

  /// The track's padding around its segments.
  static const pad = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final size = roomy ? 13.0 : 12.0;
    final corners = BorderRadius.circular(
      NushiTheme.inner(NushiTheme.control, pad),
    );
    return Container(
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: onCard ? t.lifted : t.raised,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: roomy ? 2 : 0,
        children: [
          for (final (v, text) in segments)
            Semantics(
              selected: v == value,
              child: Pressable(
                onTap: () => onChanged(v),
                tooltip: tooltip?.call(v) ?? '',
                builder: (context, look) {
                  final picked = v == value;
                  return Container(
                    height: roomy ? 28 : null,
                    padding: EdgeInsets.symmetric(
                      horizontal: roomy ? 14 : 10,
                      vertical: roomy ? 0 : 1,
                    ),
                    decoration: BoxDecoration(
                      color: picked
                          ? t.segment
                          : look.hover
                          ? _tint(t, look)
                          : null,
                      borderRadius: corners,
                      boxShadow: [
                        if (picked)
                          BoxShadow(
                            color: t.shadow,
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                      ],
                    ),
                    foregroundDecoration: focusRing(t, look, radius: corners),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        // As wide as the semibold label, picked or not.
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Room only: drawn by nothing, read by no one.
                            Visibility.maintain(
                              visible: false,
                              child: ExcludeSemantics(
                                child: RichText(
                                  textScaler: MediaQuery.textScalerOf(context),
                                  // Set as the Text over it is.
                                  text: TextSpan(
                                    text: text,
                                    style: DefaultTextStyle.of(context).style
                                        .merge(
                                          theme.ui(
                                            t.text,
                                            size: size,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              text,
                              style: theme.ui(
                                picked ? t.text : t.textSecondary,
                                size: size,
                                weight: picked ? FontWeight.w600 : null,
                              ),
                            ),
                          ],
                        ),
                        if (badges[v] case final count?)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: t.accentSoft,
                              borderRadius: BorderRadius.circular(
                                NushiTheme.pill,
                              ),
                            ),
                            child: Text(
                              count,
                              style: theme.ui(t.accentInk, size: 11.5),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
