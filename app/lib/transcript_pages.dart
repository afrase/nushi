import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';

/// At the top of a chat's transcript while more of it comes before what it
/// has (ADR 0026): a small spinner while the page before comes (asked for
/// a screen before the top shows), a still ring with Reduce Motion; once a
/// page failed, that it did, and Try again. Nothing turns while no page
/// is on its way. Always as tall, so none of it moves what's under it.
class EarlierMessages extends StatelessWidget {
  const new(this.chat, {required this.onRetry, super.key});

  final ChatState chat;
  final VoidCallback onRetry;

  /// Its height.
  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return SelectionContainer.disabled(
      child: SizedBox(
        height: height,
        child: Center(
          child: chat.olderFailed
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Couldn’t load earlier messages · ',
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.textSecondary, size: 12),
                      ),
                    ),
                    LinkText('Try again', size: 12, onTap: onRetry),
                  ],
                )
              : !chat.loadingOlder
              ? null
              : Semantics(
                  label: 'Loading earlier messages',
                  child: SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: t.textMuted,
                      // Still with Reduce Motion: a ring three parts drawn.
                      value: reduceMotion(context) ? 0.75 : null,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A transcript with [bottom] (its chat view's turn status and composer)
/// under it, and its scrollbar at the right edge of both, the pane's whole
/// height, as Claude Code's runs to the window's bottom. The list itself
/// ends above [bottom], so its edge is where a selection's drag scrolls it
/// and a toolbar over it stays in sight; the scrollbar's track runs on past
/// it ([MacScrollbar.past]). The scrollbar moves with [scroll]'s list only,
/// not with what scrolls in the composer.
class OverBottom extends StatefulWidget {
  const new({
    required this.scroll,
    required this.list,
    required this.bottom,
    super.key,
  });

  final ScrollController scroll;
  final Widget list;
  final Widget bottom;

  @override
  State<OverBottom> createState() => _OverBottomState();
}

class _OverBottomState extends State<OverBottom> {
  // How tall the bottom is, as last laid out: the scrollbar's track runs
  // past the list's foot by as much.
  final _below = ValueNotifier<double>(0);

  @override
  void dispose() {
    _below.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scroll = widget.scroll;
    return MacScrollbar(
      controller: scroll,
      past: _below,
      notificationPredicate: (n) =>
          n.depth == 0 &&
          scroll.hasClients &&
          n.context == scroll.position.context.notificationContext,
      child: CustomMultiChildLayout(
        delegate: _OverBottomLayout(_below),
        children: [
          LayoutId(id: _Part.list, child: widget.list),
          LayoutId(
            id: _Part.bottom,
            child: ColoredBox(
              color: NushiTheme.of(context).t.base,
              child: widget.bottom,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Part { list, bottom }

class _OverBottomLayout extends MultiChildLayoutDelegate {
  new(this.below);

  final ValueNotifier<double> below;

  @override
  void performLayout(Size size) {
    final bottom = layoutChild(
      _Part.bottom,
      BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: size.height,
      ),
    );
    final top = size.height - bottom.height;
    positionChild(_Part.bottom, Offset(0, top));
    layoutChild(_Part.list, BoxConstraints.tight(Size(size.width, top)));
    positionChild(_Part.list, Offset.zero);
    // Read as the scrollbar paints, after this layout.
    below.value = bottom.height;
  }

  @override
  bool shouldRelayout(_OverBottomLayout old) => old.below != below;
}

/// [list] without its own scrollbar (FullHeightScrollbar draws it); what's
/// in it has the app's back with [ownScrollbars].
Widget withoutOwnScrollbar(BuildContext context, Widget list) {
  final behavior = ScrollConfiguration.of(context);
  return ScrollConfiguration(
    behavior: behavior.copyWith(scrollbars: false),
    child: list,
  );
}

/// The app's scroll behavior again, under a [withoutOwnScrollbar] list.
Widget ownScrollbars(ScrollBehavior behavior, Widget child) =>
    ScrollConfiguration(behavior: behavior, child: child);

/// The top of [column]'s child [i] as laid out (null if it has no such
/// child), read from where its parent put it: its size is the column's to
/// read, not the list's, which reads this as it lays out.
double? topOfChild(RenderFlex column, int i) {
  var child = column.firstChild;
  for (var n = 0; n < i && child != null; n++) {
    child = column.childAfter(child);
  }
  return (child?.parentData as FlexParentData?)?.offset.dy;
}
