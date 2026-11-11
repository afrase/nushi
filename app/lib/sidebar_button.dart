import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/window_drag.dart';

part 'sidebar_glide.dart';

/// Where what's in the main pane's top may start with the sidebar hidden,
/// from the pane's left edge: past the Mac's traffic lights, which stay
/// where macOS puts them (ADR 0080), or the window's own inset
/// ([AppWindow.titleInset]), less the window's margin, which the pane is
/// already in by (ADR 0111). The phone, whose sidebar never hides, has none.
double get lightsInset =>
    kIsWeb ? 0 : max(8, native.window.titleInset - NushiTheme.windowPad);

/// Where a header's own content starts with the sidebar hidden: past the
/// lights and [ShowSidebarButton].
double get hiddenHeaderStart => lightsInset + 26 + 8;

/// Whether the sidebar is hidden, so the main area reaches the window's left
/// edge. The phone has none, whatever is saved.
bool get sidebarShut => !kIsWeb && sidebarHidden.value;

/// Hides the sidebar, or shows it again (the buttons, ⌘\, the palette and
/// the menu bar).
void toggleSidebar() => sidebarHidden.value = !sidebarHidden.value;

/// The button that hides the sidebar or shows it, the box of [LineIcon.sidebar]
/// with its left side marked off, where it rests: at the right of the
/// sidebar's header, or past the lights in a header ([header], through
/// [ShowSidebarButton]). It's one button: while the sidebar slides, neither
/// place draws it, and the one `SidebarBeside` draws over both moves from
/// one place to the other with the slide ([SidebarGlide]).
class SidebarButton extends StatelessWidget {
  const new({super.key, this.header = false}) : _moving = false;

  /// The one drawn while the sidebar slides.
  const new _moving() : header = false, _moving = true;

  /// Whether it rests in a header, past the lights, rather than in the
  /// sidebar.
  final bool header;
  final bool _moving;

  @override
  Widget build(BuildContext context) {
    final glide = context.getInheritedWidgetOfExactType<_GlideScope>()?.glide;
    final button = ValueListenableBuilder(
      valueListenable: sidebarHidden,
      builder: (context, _, _) => IconTap.line(
        LineIcon.sidebar,
        tooltip:
            '${sidebarShut ? 'Show' : 'Hide'} the sidebar '
            '(${Act.sidebar.shortcut})',
        onTap: toggleSidebar,
      ),
    );
    if (glide == null) return button;
    return _moving
        ? _Mover(glide: glide, child: button)
        : _Spot(glide: glide, header: header, child: button);
  }
}

/// [SidebarButton] in a top header's Stack, just past the lights, over the
/// header's WindowDrag so it keeps its clicks.
class ShowSidebarButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
    left: lightsInset,
    top: 0,
    bottom: 1, // the border's
    child: const Center(widthFactor: 1, child: SidebarButton(header: true)),
  );
}
