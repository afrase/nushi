import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/disclosure.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/widgets.dart';

/// A tool call's row: a one-line header in the tool rows' tint that opens
/// to show [body] ([Disclosure], its chevron turning with it); outlined
/// in red when [failed] (ADR 0076). Given [ids] (its call's, or its group's
/// and its first call's), it opens as it was left, rebuilt or not. While
/// closed, a find's matches in [folded] (what the body shows) mark the row.
class Collapsible extends StatefulWidget {
  const new({
    required this.header,
    required this.body,
    required this.failed,
    super.key,
    this.ids = const [],
    this.folded = '',
  });

  final Widget header;
  final Widget? body;
  final bool failed;
  final List<String> ids;
  final String folded;

  /// The ids of what the user opened.
  static final opened = <String>{};

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
    return framed(
      border: widget.failed ? t.crashed : t.toolBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: widget.failed ? t.crashedSoft : t.toolTint,
            child: FoldedMarks(
              text: _open ? '' : widget.folded,
              builder: (context, found) => Tap(
                onTap: body == null ? null : _toggle,
                radius: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  height: 28,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: body == null
                            ? null
                            : TurnChevron(open: _open, color: t.textSecondary),
                      ),
                      Expanded(child: widget.header),
                      FoundCount(found),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (body != null) Disclosure(open: _open, child: body),
        ],
      ),
    );
  }
}
