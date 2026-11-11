import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A group's header (a project's, Pinned's, a section's, a Date or Status
/// group's): a small muted label over its rows (ADR 0111), [lead] (an
/// agent's mark) before [title]; after it the chevron that collapses the
/// group ([onToggle]), quiet: it shows under the pointer, with the
/// keyboard's focus, and always while the group is [collapsed], when the
/// most urgent of its chats' states is one dot beside it; and [trailing]
/// at its end. As tall as a project's header with its + button, so all
/// match.
class GroupHeader extends StatefulWidget {
  const new({
    required this.title,
    required this.chats,
    required this.collapsed,
    required this.onToggle,
    super.key,
    this.lead,
    this.trailing,
    this.titleWidget,
  });

  final String title;
  final List<ChatState> chats;
  final bool collapsed;
  final VoidCallback onToggle;
  final Widget? lead;
  final Widget? trailing;

  /// In [title]'s place (a field to rename a section).
  final Widget? titleWidget;

  /// A group's name, as its header writes it.
  static TextStyle style(NushiTheme theme) =>
      theme.ui(theme.t.textMuted, size: 11.5, weight: FontWeight.w600);

  @override
  State<GroupHeader> createState() => _GroupHeaderState();
}

class _GroupHeaderState extends State<GroupHeader> {
  bool _hover = false;
  bool _focus = false; // the chevron has the keyboard's focus

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final collapsed = widget.collapsed;
    return MouseRegion(
      opaque: false,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        // Its name starts where its rows' marks do.
        padding: const EdgeInsets.fromLTRB(
          Sidebar.start + Sidebar.rowPad,
          10,
          Sidebar.end + 2,
          0,
        ),
        child: SizedBox(
          height: 26,
          child: Row(
            children: [
              if (widget.lead case final lead?) ...[
                lead,
                const SizedBox(width: 6),
              ],
              // The name takes what the row leaves; the chevron follows it.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child:
                          widget.titleWidget ??
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GroupHeader.style(theme),
                          ),
                    ),
                    _chevron(t),
                    if (collapsed) _summary(),
                  ],
                ),
              ),
              ?widget.trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _chevron(Tokens t) {
    final collapsed = widget.collapsed;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focus = f),
      child: Opacity(
        opacity: collapsed || _hover || _focus ? 1 : 0,
        child: IconTap.drawn(
          (size, color) =>
              TurnChevron(open: !collapsed, size: size, color: color),
          tooltip: collapsed ? 'Expand' : 'Collapse',
          size: 12,
          padding: 4,
          color: t.textMuted,
          onTap: widget.onToggle,
        ),
      ),
    );
  }

  /// The most urgent of its chats' states, while it's collapsed.
  Widget _summary() => ListenableBuilder(
    listenable: Listenable.merge([for (final c in widget.chats) c.look]),
    builder: (context, _) => switch (groupPhase(widget.chats)) {
      final phase? => Padding(
        padding: const EdgeInsets.only(left: 3),
        child: PhaseDot(phase),
      ),
      null => const SizedBox.shrink(),
    },
  );
}
