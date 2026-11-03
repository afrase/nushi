import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/disclosure.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/paced.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/thought_line.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/widgets.dart';

/// The agent's thinking: a dim "Thinking…" line that opens to the
/// thoughts, shining while they stream ([live]), the newest sentence
/// under it while folded ([ThoughtLine]). Once done, "Thought for 12s",
/// as long as the app watched it stream; "Thought" for one it loaded.
class ThoughtView extends StatefulWidget {
  const new(this.item, {required this.live, super.key});

  final Item item;
  final bool live;

  @override
  State<ThoughtView> createState() => _ThoughtViewState();
}

class _ThoughtViewState extends State<ThoughtView> {
  late DateTime? _since = widget.live ? DateTime.now() : null;
  Duration? _took;

  @override
  void didUpdateWidget(ThoughtView old) {
    super.didUpdateWidget(old);
    if (widget.live) _since ??= DateTime.now();
    if (old.live && !widget.live && _since != null) {
      _took = DateTime.now().difference(_since!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final took = _took;
    // Its words come as a message's do, paced ([Paced]).
    return Paced(
      widget.item.text,
      live: live,
      builder: (context, shown) => Folded(
        live
            ? 'Thinking…'
            : took == null
            ? 'Thought'
            : 'Thought for ${elapsed(took)}',
        widget.item.text,
        live: live,
        shown: shown,
        line: _since == null
            ? null
            : (style) => ThoughtLine(
                shown?.text ?? widget.item.text,
                live: live,
                style: style,
              ),
      ),
    );
  }
}

/// What streamed of a response the model's safeguards stopped (the agent
/// dropped it and went on): folded and dim, above the agent's notice.
class StoppedView extends StatelessWidget {
  const new(this.item, {super.key});

  final Item item;

  @override
  Widget build(BuildContext context) =>
      Folded('Stopped by safeguards', item.text, live: false);
}

/// A dim, italic [label] that opens to [text], shining while [live]; folded,
/// [line] under it, in its style.
class Folded extends StatefulWidget {
  const new(
    this.label,
    this.text, {
    required this.live,
    super.key,
    this.line,
    this.shown,
  });

  final String label;
  final String text;
  final bool live;
  final Widget Function(TextStyle style)? line;

  /// While [text] is paced, what of it shows, opened.
  final Shown? shown;

  @override
  State<Folded> createState() => _FoldedState();
}

class _FoldedState extends State<Folded> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final style = theme
        .ui(theme.t.textMuted, size: 12.5)
        .copyWith(fontStyle: FontStyle.italic);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FoldedMarks(
          text: _open ? '' : widget.text,
          builder: (context, found) => Tap(
            onTap: () => setState(() => _open = !_open),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                TurnChevron(open: _open),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Shine(
                      on: widget.live,
                      child: Text(widget.label, style: style),
                    ),
                    FoundCount(found),
                  ],
                ),
              ],
            ),
          ),
        ),
        // The newest sentence folds away as the thoughts open in its place.
        if (widget.line case final line?)
          Disclosure(
            open: !_open,
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: line(style),
            ),
          ),
        Disclosure(
          open: _open,
          child: Container(
            margin: const EdgeInsets.only(left: 6, top: 4),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.t.borderStrong, width: 2),
              ),
            ),
            child: switch (widget.shown) {
              final shown? => Text.rich(pacedSpan(shown, style)),
              null => Text(widget.text, style: style),
            },
          ),
        ),
      ],
    );
  }
}
