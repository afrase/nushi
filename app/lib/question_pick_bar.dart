import 'package:flutter/material.dart';

import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The bar under a waiting question's box that quotes its pick, as
/// Claude's reply bar quotes what you answer: a reply arrow, [label] (the
/// option's title in quotes, or how many are picked) on one line, "With
/// note" once the box's text goes along with it ([noted]), and × to unpick
/// ([onClear]; Esc does the same). Neutral fills only: what it quotes is
/// the user's own pick, nothing to warn of or act on.
class PickBar extends StatelessWidget {
  const new({
    required this.label,
    required this.noted,
    required this.onClear,
    super.key,
  });

  final String label;
  final bool noted;
  final VoidCallback? onClear;

  /// [names] picked as the bar says them: one quoted, more counted.
  static String says(List<String> names) =>
      names.length == 1 ? '“${names.single}”' : '${names.length} picked';

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final phone = TouchTargets.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: ControlSize.of(context).height),
      padding: const EdgeInsets.only(left: 10, right: 3),
      decoration: BoxDecoration(
        color: t.lifted,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.reply, size: 15, color: t.textSecondary),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.text),
            ),
          ),
          if (noted) const NotePill('With note'),
          IconTap(
            Icons.close,
            size: 14,
            // A phone has no keys: no key in its tooltip.
            tooltip: phone ? 'Unpick' : withKey('Unpick', 'Esc'),
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

/// A one-question card's foot: its pick's [bar] (null where the question
/// has none) and [send] at its end. The bar keeps its room while not
/// [shown], so Send stays put as a pick comes and goes: beside Send where
/// the card is wide enough for a title to read, else on a line of its own
/// over it (a phone's card).
class PickFoot extends StatelessWidget {
  const new({
    required this.bar,
    required this.shown,
    required this.send,
    super.key,
  });

  final Widget? bar;
  final bool shown;
  final Widget send;

  /// The narrowest foot that holds the bar beside Send.
  static const besideWidth = 380.0;

  @override
  Widget build(BuildContext context) {
    final end = Align(alignment: AlignmentDirectional.centerEnd, child: send);
    final bar = this.bar;
    if (bar == null) return end;
    final held = shown
        ? bar
        // Its room only: not seen, pressed, focused or read out.
        : ExcludeFocus(
            child: Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: bar,
            ),
          );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= besideWidth
          ? Row(
              spacing: 8,
              children: [
                Expanded(child: held),
                send,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [held, end],
            ),
    );
  }
}
