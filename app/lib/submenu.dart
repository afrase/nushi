import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A menu row that opens more rows beside it: Flutter's [SubmenuButton],
/// its menu placed as macOS places one. A submenu with room under its row
/// opens with its first row level with it. One without, Flutter opens
/// wholly above its row, up and away from it, so the pointer leaves both
/// menus on its way across; this one slides up only until its bottom is
/// level with its parent menu's (or the window's bottom margin, when that
/// is higher), and at most to the window's top, so it stays beside its row.
///
/// Flutter takes a menu's place as an offset from its row, given before the
/// menu has a size. So a submenu opens squeezed flat for one frame, where
/// nothing of it shows, is measured there, and is drawn in its place from
/// the next. Its offset then stays while it's open: a filtered list that
/// gets shorter keeps its top, and the field stays under the cursor.
class Submenu extends StatefulWidget {
  const new({
    required this.menuChildren,
    required this.child,
    super.key,
    this.leadingIcon,
    this.submenuIcon,
  });

  /// The room Flutter keeps between a menu and the window's edges.
  static const _margin = 8.0;

  /// A menu of no size: its rows are laid out in it, and Flutter clips all
  /// of it away, its border and shadow too.
  static const _flat = MenuStyle(
    minimumSize: WidgetStatePropertyAll(Size.zero),
    maximumSize: WidgetStatePropertyAll(Size.zero),
  );

  /// A menu no wider than its rows. Flutter draws a panel at its rows'
  /// width at the start of a box at least the theme's minimum wide, and
  /// places that box: opened to the left of its row, the panel would stand
  /// off from its parent by the difference.
  static const _snug = MenuStyle(
    minimumSize: WidgetStatePropertyAll(Size.zero),
  );

  final List<Widget> menuChildren;
  final Widget child;
  final Widget? leadingIcon;
  final WidgetStateProperty<Widget?>? submenuIcon;

  @override
  State<Submenu> createState() => _SubmenuState();
}

class _SubmenuState extends State<Submenu> {
  /// The open submenu's first row: a way into it.
  final GlobalKey<State<StatefulWidget>> _first = GlobalKey();

  /// How far above level with its row the submenu opens.
  var _up = 0.0;

  /// Whether the open submenu has its place; until then it's flat.
  var _placed = true;

  void _opened() {
    setState(() => _placed = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _placed) return;
      final up = _slide();
      setState(() {
        _up = up;
        _placed = true;
      });
    });
  }

  /// How far the submenu, laid out flat, has to go up from level with its
  /// row once it has its height; 0 when it has closed.
  double _slide() {
    final inside = _first.currentContext;
    final panel = _panel(inside);
    final rows = inside == null
        ? null
        : Scrollable.maybeOf(inside)?.context.findRenderObject();
    final row = context.findRenderObject();
    final window = Overlay.maybeOf(context)?.context.findRenderObject();
    if (panel == null ||
        rows is! RenderBox ||
        row is! RenderBox ||
        window is! RenderBox) {
      return 0;
    }
    // Where Flutter keeps menus: the window less what covers it.
    final media = MediaQuery.of(context);
    final room = media.padding.deflateRect(
      media.viewInsets.deflateRect(Offset.zero & window.size),
    );
    // The panel's top with its first row level with this one, and its
    // height when nothing squeezes it.
    final level =
        row.localToGlobal(Offset.zero, ancestor: window).dy -
        rows.localToGlobal(Offset.zero, ancestor: panel).dy;
    final height = panel.getMaxIntrinsicHeight(double.infinity);
    if (level + height <= room.bottom) return 0;
    final parent = _panel(context);
    final bottom = min(
      parent
              ?.localToGlobal(Offset(0, parent.size.height), ancestor: window)
              .dy ??
          room.bottom,
      room.bottom - Submenu._margin,
    );
    final top = max(room.top + Submenu._margin, min(level, bottom - height));
    return level - top;
  }

  /// The panel of the menu [inside] is a row of: Flutter sizes one to its
  /// widest row, so this box is the panel as drawn, and can say how high
  /// it would be.
  static RenderBox? _panel(BuildContext? inside) =>
      inside?.findAncestorRenderObjectOfType<RenderIntrinsicWidth>();

  @override
  Widget build(BuildContext context) => SubmenuButton(
    alignmentOffset: Offset(0, -_up),
    menuStyle: _placed ? Submenu._snug : Submenu._flat,
    onOpen: _opened,
    leadingIcon: widget.leadingIcon,
    submenuIcon: widget.submenuIcon,
    menuChildren: [
      for (final (i, row) in widget.menuChildren.indexed)
        if (i == 0) KeyedSubtree(key: _first, child: row) else row,
    ],
    child: widget.child,
  );
}
