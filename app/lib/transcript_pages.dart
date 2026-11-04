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
