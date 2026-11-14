import 'dart:math';

import 'package:flutter/gestures.dart' show kPrimaryButton, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/submenu.dart';
import 'package:nushi/theme/theme.dart';

/// One row of a [Menu]: [icon] (if any), [label], then [detail] dimmed on
/// the same line, its key [shortcut] and a check on the right when
/// [checked]; in red when it
/// is [danger] (it deletes or loses something). Picking it runs [onPick]; with
/// [submenu] it opens those rows beside it instead, its [detail] (the value
/// it sets) at the right before a chevron, as macOS and Claude draw one; an
/// empty [submenu] is one that can't be changed now. Without either it
/// shows unavailable. [tooltip] shows on hover. [controls], for a row that
/// isn't one choice (a chat's color): what it holds after its [label], given
/// what closes the menu; each picks for itself, and the row itself does
/// nothing.
class MenuEntry {
  const new(
    this.label, {
    this.detail = '',
    this.checked = false,
    this.onPick,
    this.submenu,
    this.tooltip = '',
    this.icon,
    this.line,
    this.mark,
    this.danger = false,
    this.shortcut = '',
    this.controls,
    this.lit = false,
    this.autofocus = false,
    this.inTap = false,
  }) : heading = false,
       custom = null;

  /// A row [custom] draws whole, given what closes the menu, as high as it
  /// needs: one that is more than a choice (a Servers menu's server, its
  /// name over its command and its ▶ at the end). It picks for itself.
  const new row(Widget Function(VoidCallback close) this.custom)
    : label = '',
      detail = '',
      checked = false,
      onPick = null,
      submenu = null,
      tooltip = '',
      icon = null,
      line = null,
      mark = null,
      danger = false,
      shortcut = '',
      controls = null,
      lit = false,
      autofocus = false,
      inTap = false,
      heading = false;

  /// A group's name over its rows.
  const new heading(this.label)
    : detail = '',
      checked = false,
      onPick = null,
      submenu = null,
      tooltip = '',
      icon = null,
      line = null,
      mark = null,
      danger = false,
      shortcut = '',
      controls = null,
      lit = false,
      autofocus = false,
      inTap = false,
      heading = true,
      custom = null;

  /// The line between groups of rows.
  static const divider = MenuEntry('');

  final String label;
  final String detail;
  final bool checked;
  final VoidCallback? onPick;
  final List<MenuEntry>? submenu;
  final String tooltip;
  final bool heading;
  final IconData? icon;

  /// A drawn icon, in [icon]'s place.
  final LineIcon? line;

  /// A widget in [icon]'s place, 16 square (an agent's mark).
  final Widget? mark;
  final bool danger;
  final String shortcut;
  final Widget Function(VoidCallback close)? controls;

  /// The row drawn whole ([MenuEntry.row]).
  final Widget Function(VoidCallback close)? custom;

  /// Marked as the row Enter picks, when the keys are handled elsewhere.
  final bool lit;

  /// Takes the focus as the menu opens, so Esc, the arrows and Enter work
  /// the menu at once, wherever the focus was (a chip over the transcript).
  final bool autofocus;

  /// Runs [onPick] in the tap itself, not a frame later as Flutter's menus
  /// do: Safari opens a file picker only from inside the tap.
  final bool inTap;

  /// Whether it can be picked or opened.
  bool get _on => onPick != null || (submenu?.isNotEmpty ?? false);

  bool get _pickable => onPick != null && submenu == null;

  bool get _hasIcon => icon != null || line != null || mark != null;
}

/// Opens the menu: under (or over) the button, or at [at] in it.
typedef OpenMenu = void Function([Offset? at]);

/// Says the [Menu]s below open from a button at the end of a row (a panel
/// widget's ⋯): under it, ending under its right edge, as macOS and Claude
/// draw a trailing button's menu. Flutter opens a menu from its opener's
/// left edge, and one with no room on its right it pushes back from the
/// window's edge by the room it was laid out in, at least the theme's
/// least width, though it draws narrower at that room's left: so a short
/// menu ended left of a button at the window's right. Only for menus their
/// button opens: one opened at a point (a right-click) would be laid out
/// from that point the other way.
class TrailingMenus extends InheritedWidget {
  const new({required super.child, super.key});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TrailingMenus>() != null;

  @override
  bool updateShouldNotify(TrailingMenus oldWidget) => false;
}

/// Sent up the tree as a [Menu] opens ([open]) and once it has closed, so
/// what holds its opener can keep its look while the pointer is on the
/// menu, which lies outside it.
class MenuOpened extends Notification {
  const new({required this.open});

  final bool open;
}

/// The app's one menu: it opens at once, without an animation, under or
/// over what [builder] draws (given the opener), or where it asks. What
/// opens it is a control of `controls.dart` (a [MenuField], a
/// [MenuButton], a [MenuIcon]) or a row's right-click: never bare text.
/// With [digits] the keys 1–9 pick its first rows, numbered on their right.
/// A list of choices longer than ten gets a filter field; an action menu
/// ([filter] false: a chat's) never does, keeping its groups and icons.
/// [onOpen] runs as it opens, [onClose] once it has closed. With [above], a
/// short menu of plain rows opens over its opener, though there's room under
/// it: for what sits at the window's bottom. [controller], given, is what
/// else opens and closes it. With [keepFocus] the pointer over a row leaves
/// the focus where it is, for a menu whose keys are handled by the text field
/// under it. With [aboveOf] an [above] menu opens over that widget instead
/// (the box its opener sits in), clear of its border, as Claude's composer
/// menu floats over its box. [largeIcons] draws the rows' icons in the
/// labels' ink and a little larger than the text, as that menu does.
class Menu extends StatefulWidget {
  const new({
    required this.entries,
    required this.builder,
    super.key,
    this.digits = false,
    this.filter = true,
    this.above = false,
    this.keepFocus = false,
    this.aboveOf,
    this.largeIcons = false,
    this.controller,
    this.onOpen,
    this.onClose,
  });

  /// A row's height, a phone's taller, and the panel's padding and border,
  /// in the theme's menu.
  static const _row = 30.0;
  static const _touchRow = 48.0;
  static const _edges = 12.0;

  final List<MenuEntry> entries;
  final Widget Function(BuildContext context, OpenMenu open) builder;
  final bool digits;
  final bool filter;
  final bool above;
  final bool keepFocus;
  final GlobalKey? aboveOf;
  final bool largeIcons;
  final MenuController? controller;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  State<Menu> createState() => _MenuState();
}

/// How many menus are open: a key typed while one is goes to it, not to
/// the chat's box (ADR 0121).
final ValueNotifier<int> openMenus = runValue(0);

class _MenuState extends State<Menu> {
  late final MenuController _menu = widget.controller ?? MenuController();
  final _focus = FocusNode(debugLabel: 'menu');

  /// Whether this one counts in [openMenus].
  bool _counted = false;

  void _count({required bool open}) {
    if (open == _counted) return;
    _counted = open;
    openMenus.value += open ? 1 : -1;
  }

  @override
  void dispose() {
    _count(open: false);
    _focus.dispose();
    super.dispose();
  }

  double _height(BuildContext context) {
    final padded =
        Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded;
    final row = padded ? Menu._touchRow : Menu._row;
    return widget.entries.fold(
      Menu._edges,
      (h, e) => h + (identical(e, MenuEntry.divider) ? _dividerHeight : row),
    );
  }

  void _open([Offset? at]) {
    if (_menu.isOpen && at == null) return _menu.close();
    _menu.open(position: at ?? _overOf());
  }

  /// Where an [Menu.above] menu opens over [Menu.aboveOf], from the
  /// opener's top left, as laid out now; null without one.
  Offset? _overOf() {
    final over = widget.aboveOf?.currentContext?.findRenderObject();
    final opener = context.findRenderObject();
    if (!widget.above || over is! RenderBox || opener is! RenderBox) {
      return null;
    }
    final top =
        over.localToGlobal(Offset.zero).dy -
        opener.localToGlobal(Offset.zero).dy;
    return Offset(0, top - _height(context) - _aboveGap);
  }

  /// The room between a menu opened over [Menu.aboveOf] and it.
  static const _aboveGap = 6.0;

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final n = int.tryParse(e.character ?? '') ?? 0;
    final picks = widget.entries.where((e) => e._pickable).take(9).toList();
    if (!widget.digits || e is! KeyDownEvent || n < 1 || n > picks.length) {
      return KeyEventResult.ignored;
    }
    _menu.close();
    picks[n - 1].onPick!();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!TrailingMenus.of(context)) return _anchor(context);
    // Flutter lays a menu out from its opener's start edge, toward the
    // text's end, so a trailing button's menu is laid out as in the other
    // direction, from its end edge; its opener and rows keep the real one.
    final real = Directionality.of(context);
    return Directionality(
      textDirection: real == TextDirection.ltr
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: _anchor(context, real: real),
    );
  }

  /// The menu, its opener and rows in [real] when it's laid out in the
  /// other direction.
  Widget _anchor(BuildContext context, {TextDirection? real}) => Focus(
    focusNode: _focus,
    skipTraversal: true, // focused only while the menu is open
    onKeyEvent: _onKey,
    child: MenuAnchor(
      controller: _menu,
      style: widget.above
          ? const MenuStyle(alignment: AlignmentDirectional.topStart)
          : null,
      // Flutter only opens one upward when it wouldn't fit under.
      alignmentOffset: widget.above
          ? Offset(0, -_height(context) - 4)
          : Offset.zero,
      menuChildren: [
        for (final row in _rows(
          context,
          widget.entries,
          _menu.close,
          digits: widget.digits,
          filter: widget.filter,
          keepFocus: widget.keepFocus,
          largeIcons: widget.largeIcons,
        ))
          if (real == null)
            row
          else
            Directionality(
              textDirection: real,
              // Where the row sits in the real direction.
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: row,
              ),
            ),
      ],
      onOpen: () {
        _count(open: true);
        if (widget.digits) _focus.requestFocus();
        const MenuOpened(open: true).dispatch(context);
        widget.onOpen?.call();
      },
      // After the menu has settled its own focus.
      onClose: () => WidgetsBinding.instance.addPostFrameCallback((_) {
        _count(open: false);
        if (mounted) const MenuOpened(open: false).dispatch(context);
        widget.onClose?.call();
      }),
      child: real == null
          ? widget.builder(context, _open)
          : Directionality(
              textDirection: real,
              child: widget.builder(context, _open),
            ),
    ),
  );
}

/// Lists longer than this get a filter field.
const _filterPast = 10;

/// The height of the line between a menu's groups.
const _dividerHeight = 11.0;

/// A row's text's inset from the panel's padding (the menu buttons' theme).
const _rowInset = 10.0;

/// The width of a row's check, and of a submenu's chevron under it.
const _check = 14.0;

List<Widget> _rows(
  BuildContext context,
  List<MenuEntry> entries,
  VoidCallback close, {
  bool digits = false,
  bool filter = true,
  bool keepFocus = false,
  bool largeIcons = false,
}) {
  if (filter && entries.where((e) => e._pickable).length > _filterPast) {
    return [_Filtered(entries, close)];
  }
  final theme = NushiTheme.of(context);
  final t = theme.t;
  var n = 0;
  // Rows without an icon keep its room when others have one, so the
  // labels line up; the check's room only where a row can have one, so a
  // key sits at the right edge, as macOS draws it.
  final icons = entries.any((e) => e._hasIcon);
  final checks = entries.any((e) => e.checked);
  return [
    for (final e in entries)
      if (identical(e, MenuEntry.divider))
        // From the rows' text to their end, as Claude's.
        const Divider(
          height: _dividerHeight,
          indent: _rowInset,
          endIndent: _rowInset,
        )
      else if (e.heading)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 3),
          child: Text(e.label, style: theme.ui(t.textMuted, size: 12)),
        )
      else if (e.custom case final custom?)
        custom(close)
      else if (e.controls case final controls?)
        _controlsRow(context, e, controls(close), icons: icons)
      else
        _row(
          context,
          e,
          close,
          icons: icons,
          largeIcons: largeIcons,
          checks: checks,
          keepFocus: keepFocus,
          digit: !digits
              ? null
              : e._pickable && n < 9
              ? '${++n}'
              : '',
        ),
  ];
}

/// A row of [e]'s [controls] after its label, as high as the others and
/// lined up with them; a menu's width grows to take it.
Widget _controlsRow(
  BuildContext context,
  MenuEntry e,
  Widget controls, {
  required bool icons,
}) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  return ConstrainedBox(
    constraints: const BoxConstraints(minHeight: Menu._row),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          if (icons)
            SizedBox(
              width: 16,
              child: e.icon == null
                  ? null
                  : Icon(e.icon, size: 16, color: t.textSecondary),
            ),
          if (icons) const SizedBox(width: 8),
          Text(
            e.label,
            style: theme.ui(t.text, size: 13.5, weight: FontWeight.w400),
          ),
          const SizedBox(width: 12),
          const Spacer(),
          controls,
        ],
      ),
    ),
  );
}

/// A row: [digit] shows its key on the right; [lit] marks it as the one
/// Enter picks.
Widget _row(
  BuildContext context,
  MenuEntry e,
  VoidCallback close, {
  String? digit,
  bool lit = false,
  bool icons = false,
  bool largeIcons = false,
  bool checks = true,
  bool keepFocus = false,
  Key? key,
}) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  final on = e._on;
  final color = !on
      ? t.textMuted
      : e.danger
      ? t.crashed
      : t.text;
  final iconColor = !on
      ? t.textMuted
      : e.danger
      ? t.crashed
      : largeIcons
      ? t.text
      : t.textSecondary;
  // A phone's larger text takes its icons with it.
  final iconSize = largeIcons
      ? MediaQuery.textScalerOf(context).scale(18)
      : 16.0;
  final icon = icons
      ? SizedBox(
          width: iconSize,
          child:
              e.mark ??
              e.line?.view(size: iconSize, color: iconColor) ??
              (e.icon == null
                  ? null
                  : Icon(e.icon, size: iconSize, color: iconColor)),
        )
      : null;
  // Narrower on a narrow screen (the phone's), so the menu fits on it.
  final screen = MediaQuery.sizeOf(context).width;
  Widget label = ConstrainedBox(
    constraints: BoxConstraints(maxWidth: max(120, min(380, screen - 150))),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: e.label,
            style: theme.ui(color, size: 13.5, weight: FontWeight.w400),
          ),
          if (e.detail.isNotEmpty && e.submenu == null)
            TextSpan(
              text: '   ${e.detail}',
              style: theme.ui(t.textMuted, size: 12.5, weight: FontWeight.w400),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
  if (e.tooltip.isNotEmpty) label = tooltip(context, e.tooltip, label);
  if (e.submenu case final sub?) {
    // Its value and chevron as the one decoration, so the row's space
    // goes before them and they sit at its end.
    final end = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        if (e.detail.isNotEmpty)
          Text(
            e.detail,
            style: theme.ui(t.textMuted, size: 12.5, weight: FontWeight.w400),
          ),
        LineIcon.chevron.view(
          size: _check,
          color: on ? t.textSecondary : color,
        ),
      ],
    );
    return Submenu(
      key: key,
      leadingIcon: icon,
      submenuIcon: WidgetStatePropertyAll(end),
      menuChildren: _rows(context, sub, close),
      child: Padding(padding: const EdgeInsets.only(right: 12), child: label),
    );
  }
  return _button(
    theme,
    e,
    label,
    digit: digit,
    lit: lit || e.lit,
    icon: icon,
    checks: checks,
    keepFocus: keepFocus,
    key: key,
  );
}

Widget _button(
  NushiTheme theme,
  MenuEntry e,
  Widget label, {
  required String? digit,
  required bool lit,
  required bool checks,
  bool keepFocus = false,
  Widget? icon,
  Key? key,
  VoidCallback? onPressed,
}) {
  final t = theme.t;
  if (e.inTap && e.onPick != null && onPressed == null) {
    return _InTap(
      key: key,
      onPick: e.onPick!,
      builder: (onPressed) => _button(
        theme,
        e,
        label,
        digit: digit,
        lit: lit,
        checks: checks,
        keepFocus: keepFocus,
        icon: icon,
        onPressed: onPressed,
      ),
    );
  }
  return MenuItemButton(
    key: key,
    onPressed: onPressed ?? e.onPick,
    autofocus: e.autofocus,
    requestFocusOnHover: !keepFocus,
    leadingIcon: icon,
    style: lit ? MenuItemButton.styleFrom(backgroundColor: t.hover) : null,
    trailingIcon: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (e.shortcut.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: keyText(
              e.shortcut,
              // The label's font; its keys' symbols from the bundled code
              // font, which has them.
              theme.ui(t.textMuted).thenFonts(const [NushiTheme.codeFont]),
            ),
          ),
        if (checks)
          // The accent's, as Claude's and the app's other checks.
          SizedBox(
            width: _check,
            child: e.checked
                ? Icon(Icons.check, size: _check, color: t.accentInk)
                : null,
          ),
        if (digit != null)
          SizedBox(
            width: 22,
            child: Text(
              digit,
              textAlign: TextAlign.right,
              style: theme.ui(t.textMuted, size: 12.5),
            ),
          ),
      ],
    ),
    child: Padding(padding: const EdgeInsets.only(right: 12), child: label),
  );
}

/// A long list under a field that takes the focus and narrows it by name
/// and description as you type. ↑ and ↓ move, Enter picks, Escape clears
/// the field, then closes the menu.
class _Filtered extends StatefulWidget {
  const new(this.entries, this.close);

  final List<MenuEntry> entries;
  final VoidCallback close;

  @override
  State<_Filtered> createState() => _FilteredState();
}

class _FilteredState extends State<_Filtered> {
  final _text = TextEditingController();
  final GlobalKey<State<StatefulWidget>> _lit = GlobalKey();
  // The row Enter picks, of those shown: the current one at first.
  late int _at = max(0, _shown.indexWhere((e) => e.checked));

  /// Opens on the current row, wherever it is in a long list (a font
  /// among hundreds), in the middle of what shows.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lit.currentContext case final c? when _at > 0) {
        Scrollable.ensureVisible(c, alignment: 0.5);
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<MenuEntry> get _shown {
    final q = _text.text.trim().toLowerCase();
    return [
      for (final e in widget.entries)
        if (e._pickable &&
            '${e.label} ${e.detail} ${e.tooltip}'.toLowerCase().contains(q))
          e,
    ];
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final shown = _shown;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowUp
          when shown.isNotEmpty:
        final step = e.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
        setState(() => _at = (_at + step) % shown.length);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_lit.currentContext case final c?) Scrollable.ensureVisible(c);
        });
      case LogicalKeyboardKey.enter when _at < shown.length:
        widget.close();
        shown[_at].onPick!();
      case LogicalKeyboardKey.escape when _text.text.isNotEmpty:
        _text.clear();
        setState(() => _at = 0);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final shown = _shown;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          onKeyEvent: _onKey,
          skipTraversal: true,
          child: TextField(
            controller: _text,
            autofocus: true,
            style: theme.ui(t.text),
            onChanged: (_) => setState(() => _at = 0),
            decoration: const InputDecoration(
              hintText: 'Filter',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, size: 15),
              prefixIconConstraints: BoxConstraints(minWidth: 28),
            ),
          ),
        ),
        const Divider(height: 1),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, e) in shown.indexed)
                  _row(
                    context,
                    e,
                    widget.close,
                    icons: widget.entries.any((e) => e._hasIcon),
                    lit: i == _at,
                    key: i == _at ? _lit : null,
                  ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('No match', style: theme.ui(t.textMuted)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A row whose pick runs in the tap itself ([MenuEntry.inTap]): as the
/// finger lifts where it went down, before Flutter's button, which runs its
/// own a frame later (and still does for the keyboard's Enter).
class _InTap extends StatefulWidget {
  const new({required this.onPick, required this.builder, super.key});

  final VoidCallback onPick;
  final Widget Function(VoidCallback onPressed) builder;

  @override
  State<_InTap> createState() => _InTapState();
}

class _InTapState extends State<_InTap> {
  Offset? _down;
  bool _ran = false;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) {
      // Only a primary press picks, as Flutter's button has it: a
      // right-click on the row does nothing, and leaves Enter its pick.
      if (e.buttons != kPrimaryButton) {
        _down = null;
        return;
      }
      _down = e.position;
      _ran = false;
    },
    onPointerCancel: (_) => _down = null,
    onPointerUp: (e) {
      final down = _down;
      _down = null;
      if (down == null || (e.position - down).distance > kTouchSlop) return;
      _ran = true;
      widget.onPick();
    },
    child: widget.builder(() {
      if (!_ran) widget.onPick();
      _ran = false;
    }),
  );
}
