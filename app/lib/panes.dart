import 'package:flutter/material.dart';
import 'package:nushi/controls.dart';

import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/window_drag.dart';

export 'package:nushi/resizable.dart';

/// A pane of the window (ADR 0111): [child] on the pane's fill, its corners
/// rounded and what's in it cut to them. The window's own background shows
/// around it; the main area is one. Its lists' scrollbars keep clear of its
/// corners ([RoundedScroll]).
class Pane extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: NushiTheme.of(context).t.base,
      borderRadius: BorderRadius.circular(NushiTheme.panel),
    ),
    child: RoundedScroll(corner: NushiTheme.panel, child: child),
  );
}

/// A header inside a pane: as high as the chat header ([PaneHeader.height])
/// with a hairline under it and no fill of its own (ADR 0111), [child] its
/// row (a side chat's, a subagent's, a command's, a preview's), [inset] from
/// the left and [end] from the right: by default the gutters, or what the
/// row has always had in a pane too narrow for them. [plain] is a view's
/// header, at the main pane's top; with the sidebar hidden such a header
/// runs under the traffic lights, so its row starts past them and past the
/// button that shows the sidebar. Empty space in it moves the window (ADR
/// 0080). A plain header's [lead], before [child] and taking the room it
/// leaves, moves with the sidebar's edge as the sidebar slides
/// ([SidebarFollow]); [child] stays put.
class PaneHeader extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.inset,
    this.end,
    this.plain = false,
    this.lead,
  });

  /// The chat header's height too (ADR 0111; 44 until then, ADR 0072).
  static const height = 56.0;

  /// How far in from a pane's right a row ending in the header's own icon
  /// buttons (`IconTap.header`) ends them, as the chat's header does (ADR
  /// 0111): the button's box brings the rest of the room.
  static const buttonsEnd = 12.0;

  /// Below this a pane's header keeps its row's room over the gutters: a side
  /// chat's title and buttons take most of the narrowest pane.
  static const gutterFrom = 320.0;

  final Widget child;
  final double? inset;
  final double? end;
  final bool plain;
  final Widget? lead;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ListenableBuilder(
      listenable: sidebarHidden,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final room = box.maxWidth >= gutterFrom;
          final shut = plain && sidebarShut;
          return SizedBox(
            height: height,
            child: WindowDrag(
              background: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: shut
                        ? hiddenHeaderStart
                        : inset ?? (room ? NushiTheme.gutter : 14),
                    right: end ?? (room ? NushiTheme.gutter : 4),
                    bottom: 1, // the border's
                  ),
                  child: switch (lead) {
                    final lead? => Row(
                      children: [
                        Expanded(
                          child: SidebarFollow(
                            shut: shut,
                            clip: true,
                            child: lead,
                          ),
                        ),
                        child,
                      ],
                    ),
                    null => child,
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The strip of the window's own background above the panes (ADR 0111),
/// which does what the top of a title bar did: a drag there moves the
/// window, a double click zooms it. Nothing where the headers don't move
/// the window.
class WindowEdge extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: NushiTheme.windowPad,
    child: WindowDrag(background: SizedBox.shrink(), children: []),
  );
}

/// [child] under a band across the window's top, a header's height, that
/// does what a title bar did (ADR 0080) for what covers the window with no
/// header of its own (the daemon's start and its update, Settings' dim): a
/// drag there moves the window and a double click zooms it. AppKit's own
/// title bar no longer takes that strip, so without the band nothing would
/// move the window. A click on it does [onTap], as one on what's under it
/// did (a click on Settings' dim shuts Settings). Where the headers don't
/// move the window ([headersMoveWindow]), it's [child] alone, whose own
/// clicks do the rest.
class TitleBand extends StatelessWidget {
  const new({required this.child, super.key, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => !headersMoveWindow
      ? child
      : Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: NushiTheme.windowPad + PaneHeader.height,
              child: WindowDrag(
                background: const SizedBox.shrink(),
                children: [
                  if (onTap case final onTap?)
                    // design: the header's tap beside the window's drag
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                    ),
                ],
              ),
            ),
          ],
        );
}

/// The buttons at a wide side pane's top row's right end, the Files pane's
/// and the browser's alike, as Claude desktop's: Expand (Collapse while
/// [expanded]), when [onExpand] is given, and × ([onClose]). Each sits in
/// a box of one size, ending 8 in from the pane's edge with the row's
/// `end`, so both panes put them at the same pixels.
class PaneEndButtons extends StatelessWidget {
  const new({
    required this.onClose,
    super.key,
    this.expanded = false,
    this.onExpand,
  });

  final bool expanded;
  final VoidCallback? onExpand;
  final VoidCallback onClose;

  /// The side of each button's box.
  static const box = 32.0;

  /// The room at the row's ends, in from the pane's edges (Claude's).
  static const inset = 8.0;

  /// The padding that sets an icon of [size] in a [box].
  static double boxed(double size) => (box - size) / 2;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final expand = onExpand;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (expand != null)
          IconTap.line(
            expanded ? LineIcon.collapse : LineIcon.expand,
            tooltip: expanded ? 'Collapse' : 'Expand',
            size: 18,
            padding: boxed(18),
            color: t.text,
            onTap: expand,
          ),
        IconTap.line(
          LineIcon.close,
          tooltip: 'Close',
          size: 22,
          padding: boxed(22),
          color: t.text,
          onTap: onClose,
        ),
      ],
    );
  }
}
