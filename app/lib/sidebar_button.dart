import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/native.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

part 'sidebar_glide.dart';

/// Where what's in the main pane's top may start with the sidebar hidden,
/// from the pane's left edge: past the Mac's traffic lights, which sit
/// level with the header's middle (ADR 0111), or the window's own inset
/// (`AppWindow.titleInset`), less the window's margin, which the pane is
/// already in by (ADR 0111). The phone, whose sidebar never hides, has none.
double get lightsInset =>
    kIsWeb ? 0 : max(8, native.window.titleInset - NushiTheme.windowPad);

/// Where a header's own content starts with the sidebar hidden, from the
/// pane's left edge: past the lights and [TitleButtons], with the room a
/// header's icon button leaves around its icon after them.
double get hiddenHeaderStart =>
    TitleButtons.right - NushiTheme.windowPad + SidebarButton.iconInset;

/// Whether the sidebar is hidden, so the main area reaches the window's left
/// edge. The phone has none, whatever is saved.
bool get sidebarShut => !kIsWeb && sidebarHidden.value;

/// Hides the sidebar, or shows it again (the button, ⌘\, the palette and
/// the menu bar).
void toggleSidebar() => sidebarHidden.value = !sidebarHidden.value;

/// The button that hides the sidebar or shows it, the box of
/// [LineIcon.sidebar] with its left side marked off. It's the first of
/// [TitleButtons], at one place in the window whether the sidebar shows or
/// not (ADR 0116: a toggle never moves when pressed), and the same control
/// as the icon buttons at a header's right (32 square, [IconTap.header];
/// ADR 0111), so the two ends of the top match.
class SidebarButton extends StatelessWidget {
  const new({super.key});

  /// How far in from its box its icon sits less a header's icon button's
  /// room around it: the icon is [iconInset] past where the lights leave
  /// room ([lightsInset]).
  static const iconInset = 5.0;

  /// How far its box reaches before that place, around the icon.
  static const double reach = IconTap.header - iconInset;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: sidebarHidden,
    builder: (context, _, _) => IconTap.line(
      LineIcon.sidebar,
      tooltip:
          '${sidebarShut ? 'Show' : 'Hide'} the sidebar '
          '(${Act.sidebar.shortcut})',
      padding: IconTap.header,
      onTap: toggleSidebar,
    ),
  );
}

/// The buttons at the window's top left, past the traffic lights, level
/// with the headers' middle: [SidebarButton], then Back and Forward
/// through the places visited (`goBack`, ADR 0117), each greyed
/// out while there's nowhere to go. They're drawn over the
/// sidebar's top strip and the main pane's header alike, at the same place
/// in the window whether the sidebar shows, is hidden or slides (ADR
/// 0116); `SidebarBeside` puts them there. [onSidebarHover] hears the
/// pointer come onto the sidebar's button and leave it.
class TitleButtons extends StatelessWidget {
  const new({required this.daemon, super.key, this.onSidebarHover});

  final Daemon daemon;
  final ValueChanged<bool>? onSidebarHover;

  /// A button's box: a header's icon button.
  static const double _box = 16 + 2 * IconTap.header;

  /// How many there are.
  static const _count = 3;

  /// Where they start, from the window's left edge: the first one's icon
  /// [SidebarButton.iconInset] past the lights.
  static double get left =>
      NushiTheme.windowPad + lightsInset - SidebarButton.reach;

  /// How wide they are together.
  static double get width => _count * _box + (_count - 1) * NushiTheme.iconGap;

  /// Where they end, from the window's left edge.
  static double get right => left + width;

  /// How far down from the window's top they are, and how tall: a header's
  /// row, under the window's margin, less its hairline.
  static const double top = NushiTheme.windowPad;
  static const double height = PaneHeader.height - 1;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => onSidebarHover?.call(true),
          onExit: (_) => onSidebarHover?.call(false),
          child: const SidebarButton(),
        ),
        const SizedBox(width: NushiTheme.iconGap),
        // What they can do changes as the daemon does: a chat archived or
        // deleted is passed over.
        ListenableBuilder(
          listenable: daemon,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTap.line(
                LineIcon.chevronBack,
                tooltip: 'Back (${Act.back.shortcut})',
                padding: IconTap.header,
                onTap: daemon.canGoBack ? daemon.goBack : null,
              ),
              const SizedBox(width: NushiTheme.iconGap),
              IconTap.line(
                LineIcon.chevronForward,
                tooltip: 'Forward (${Act.forward.shortcut})',
                padding: IconTap.header,
                onTap: daemon.canGoForward ? daemon.goForward : null,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
