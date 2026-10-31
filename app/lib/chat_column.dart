import 'package:flutter/widgets.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/github_text.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

/// The room beside the chat's column in a space [width] wide (ADR 0074):
/// on the Mac the gutter at full width ([chatFullWidth]), otherwise what
/// centres [readableWidth]; on the phone its own 20.
EdgeInsets chatSides(BuildContext context, double width) {
  if (TouchTargets.of(context)) {
    return const EdgeInsets.symmetric(horizontal: 20);
  }
  return EdgeInsets.symmetric(
    horizontal: chatFullWidth.value ? NushiTheme.gutter : readablePad(width),
  );
}

/// [child], which has its own gutters, in the chat's column: its edges are
/// the transcript's text's (the composer, the lines over it).
class ChatColumn extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => TouchTargets.of(context)
      ? child
      : LayoutBuilder(
          builder: (context, box) {
            final sides = chatSides(context, box.maxWidth);
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: sides.left - NushiTheme.gutter,
              ),
              child: child,
            );
          },
        );
}
