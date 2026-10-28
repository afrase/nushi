import 'package:flutter/material.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A tool call's card: a one-line header in the tool rows' tint that
/// opens to show [body], its height easing open and its chevron turning;
/// outlined in red when [failed]. Given [ids] (its call's, or its group's
/// and its first call's), it opens as it was left, rebuilt or not.
class Collapsible extends StatefulWidget {
  const new({
    required this.header,
    required this.body,
    required this.failed,
    super.key,
    this.ids = const [],
  });

  final Widget header;
  final Widget? body;
  final bool failed;
  final List<String> ids;

  /// The ids of what the user opened.
  static final opened = <String>{};

  @override
  State<Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<Collapsible>
    with SingleTickerProviderStateMixin {
  late bool _open = widget.ids.any(Collapsible.opened.contains);
  late final _opening =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        value: _open ? 1 : 0,
      )..addStatusListener((s) {
        // Closed: the body goes.
        if (s == AnimationStatus.dismissed) setState(() {});
      });
  late final _eased = CurvedAnimation(parent: _opening, curve: Curves.ease);

  @override
  void dispose() {
    _eased.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (widget.ids.isEmpty) return;
      _open
          ? Collapsible.opened.add(widget.ids.first)
          : Collapsible.opened.removeAll(widget.ids);
    });
    if (reduceMotion(context)) {
      _opening.value = _open ? 1 : 0;
    } else {
      (_open ? _opening.forward() : _opening.reverse()).ignore();
    }
  }

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
            child: Tap(
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
                          : RotationTransition(
                              turns: Tween(
                                begin: 0.0,
                                end: 0.25,
                              ).animate(_eased),
                              child: Chevron(
                                open: false,
                                color: t.textSecondary,
                              ),
                            ),
                    ),
                    Expanded(child: widget.header),
                  ],
                ),
              ),
            ),
          ),
          if (body != null && (_open || !_opening.isDismissed))
            SizeTransition(
              sizeFactor: _eased,
              alignment: Alignment.topCenter,
              child: body,
            ),
        ],
      ),
    );
  }
}
