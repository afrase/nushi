import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/settings.dart';

/// Where what's in the main area's top may start with the sidebar hidden:
/// past the traffic lights, which stay where macOS puts them (ADR 0080).
const lightsInset = 84.0;

/// Where a header's own content starts with the sidebar hidden: past the
/// lights and [ShowSidebarButton].
const double hiddenHeaderStart = lightsInset + 26 + 8;

/// Whether the sidebar is hidden, so the main area reaches the window's left
/// edge. The phone has none, whatever is saved.
bool get sidebarShut => !kIsWeb && sidebarHidden.value;

/// Hides the sidebar, or shows it again (the buttons, ⌘\, the palette and
/// the menu bar).
void toggleSidebar() => sidebarHidden.value = !sidebarHidden.value;

/// The button that hides the sidebar or shows it, the box of [LineIcon.sidebar]
/// with its left side marked off.
class SidebarButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => IconTap.line(
    LineIcon.sidebar,
    tooltip:
        '${sidebarShut ? 'Show' : 'Hide'} the sidebar '
        '(${Act.sidebar.shortcut})',
    onTap: toggleSidebar,
  );
}

/// [SidebarButton] in a top header's Stack, just past the lights, over the
/// header's WindowDrag so it keeps its clicks.
class ShowSidebarButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const Positioned(
    left: lightsInset,
    top: 0,
    bottom: 1, // the border's
    child: Center(widthFactor: 1, child: SidebarButton()),
  );
}
