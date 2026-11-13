import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/disclosure.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/widgets.dart';

/// A tool call's row (ADR 0111): a one-line header on a card's fill, no
/// outline, that opens to show [body] ([Disclosure], its chevron turning
/// with it). Open, the card holds the body in a block of code's surface
/// ([sunk]; a run's rows sit straight on the card), its header where it
/// was. [nested], it's a call in an open run: a row of the run's card with
/// no fill of its own, and open, the sunk block around its header and body.
/// Given [ids] (its call's, or its group's and its first call's), it opens
/// as it was left, rebuilt or not. While closed, a find's matches in
/// [folded] (what the body shows) mark the row.
class Collapsible extends StatefulWidget {
  const new({
    required this.header,
    required this.body,
    super.key,
    this.ids = const [],
    this.folded = '',
    this.nested = false,
    this.sunk = true,
  });

  final Widget header;
  final Widget? body;
  final List<String> ids;
  final String folded;
  final bool nested;
  final bool sunk;

  /// A row's height, and a [nested] one's; a phone's is its touch target.
  static const height = 36.0;
  static const nestedHeight = 34.0;

  /// A card's padding around what an open row holds, and so what its
  /// header's own is less by when [nested].
  static const inset = 4.0;

  /// The room beside a row's words, from the card's edge.
  static const side = 12.0;

  /// The ids of what the user opened.
  static final Set<String> opened = runSet();

  @override
  State<Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<Collapsible> {
  late bool _open = widget.ids.any(Collapsible.opened.contains);

  void _toggle() => setState(() {
    _open = !_open;
    if (widget.ids.isEmpty) return;
    _open
        ? Collapsible.opened.add(widget.ids.first)
        : Collapsible.opened.removeAll(widget.ids);
  });

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final body = widget.body;
    final nested = widget.nested;
    final open = _open && body != null;
    final side = Collapsible.side - (nested ? Collapsible.inset : 0);
    final header = FoldedMarks(
      text: _open ? '' : widget.folded,
      builder: (context, found) => Tap(
        onTap: body == null ? null : _toggle,
        radius: 0, // the card's corners cut it
        padding: EdgeInsets.symmetric(horizontal: side),
        child: SizedBox(
          height: nested ? Collapsible.nestedHeight : Collapsible.height,
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: body == null
                    ? null
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: TurnChevron(open: _open, color: t.textSecondary),
                      ),
              ),
              Expanded(child: widget.header),
              FoundCount(found),
            ],
          ),
        ),
      ),
    );
    // What a sunk block is rounded by, set [Collapsible.inset] in a card.
    final block = BorderRadius.circular(
      NushiTheme.inner(NushiTheme.card, Collapsible.inset),
    );
    if (nested) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: open ? t.codeBlock : null,
          borderRadius: block,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (body != null)
              Disclosure(
                open: _open,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(side, 0, side, 10),
                  child: body,
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.raised,
        // A control's corners while it's one row (a card's would round 36
        // points into a lozenge, ADR 0110); a card's once it holds more.
        borderRadius: BorderRadius.circular(
          open ? NushiTheme.card : NushiTheme.control,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (body != null)
            Disclosure(
              open: _open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Collapsible.inset,
                  0,
                  Collapsible.inset,
                  Collapsible.inset,
                ),
                child: widget.sunk
                    ? Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: t.codeBlock,
                          borderRadius: block,
                        ),
                        child: body,
                      )
                    : body,
              ),
            ),
        ],
      ),
    );
  }
}
