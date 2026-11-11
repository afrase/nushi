import 'package:flutter/widgets.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

/// The widest the chat's column goes (ADR 0111): the transcript's text,
/// the cards in it and the composer.
const chatWidth = 800.0;

/// The room beside the chat's column in a space [width] wide (ADR 0074):
/// on the Mac the gutter at full width ([chatFullWidth]), otherwise what
/// centres [chatWidth]; on the phone its own 20.
EdgeInsets chatSides(BuildContext context, double width) {
  if (TouchTargets.of(context)) {
    return const EdgeInsets.symmetric(horizontal: 20);
  }
  const gutter = NushiTheme.gutter;
  final wide = !chatFullWidth.value && width - 2 * gutter > chatWidth;
  return EdgeInsets.symmetric(
    horizontal: wide ? (width - chatWidth) / 2 : gutter,
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
