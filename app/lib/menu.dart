import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/theme.dart';
import 'widgets.dart';

/// One row of a [Menu]: [label], then [detail] dimmed on the same line, and
/// a check on the right when [checked]. Picking it runs [onPick]; with
/// [submenu] it opens those rows beside it instead. Without either it
/// shows unavailable. [tooltip] shows on hover.
class MenuEntry {
  const MenuEntry(
    this.label, {
    this.detail = '',
    this.checked = false,
    this.onPick,
    this.submenu,
    this.tooltip = '',
  }) : heading = false;

  /// A group's name over its rows.
  const MenuEntry.heading(this.label)
    : detail = '',
      checked = false,
      onPick = null,
      submenu = null,
      tooltip = '',
      heading = true;

  /// The line between groups of rows.
  static const divider = MenuEntry('');

  final String label;
  final String detail;
  final bool checked;
  final VoidCallback? onPick;
  final List<MenuEntry>? submenu;
  final String tooltip;
  final bool heading;

  bool get _pickable => onPick != null && submenu == null;
}

/// Opens the menu: under (or over) the button, or at [at] in it.
typedef OpenMenu = void Function([Offset? at]);

/// The app's one menu: it opens at once, without an animation, under or
/// over its button ([child], with [tooltip]), or wherever [builder] asks.
/// With [digits] the keys 1–9 pick its first rows, numbered on their right.
/// [onClose] runs once it has closed.
class Menu extends StatefulWidget {
  const Menu({
    super.key,
    required this.entries,
    this.child,
    this.tooltip = '',
    this.builder,
    this.digits = false,
    this.onClose,
  });

  final List<MenuEntry> entries;
  final Widget? child;
  final String tooltip;
  final Widget Function(BuildContext context, OpenMenu open)? builder;
  final bool digits;
  final VoidCallback? onClose;

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  final _menu = MenuController();
  final _focus = FocusNode(debugLabel: 'menu');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _open([Offset? at]) =>
      _menu.isOpen && at == null ? _menu.close() : _menu.open(position: at);

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
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    onKeyEvent: _onKey,
    child: MenuAnchor(
      controller: _menu,
      menuChildren: _rows(context, widget.entries, digits: widget.digits),
      onOpen: () {
        if (widget.digits) _focus.requestFocus();
      },
      // After the menu has settled its own focus.
      onClose: () => WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onClose?.call(),
      ),
      child:
          widget.builder?.call(context, _open) ??
          Tap(
            tooltip: widget.tooltip,
            onTap: _open,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: widget.child!,
          ),
    ),
  );
}

List<Widget> _rows(
  BuildContext context,
  List<MenuEntry> entries, {
  bool digits = false,
}) {
  final theme = NushiTheme.of(context), t = theme.t;
  var n = 0;
  Widget row(MenuEntry e) {
    final on = e.onPick != null || e.submenu != null;
    Widget label = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: e.label,
              style: theme.ui(
                on ? t.text : t.textMuted,
                weight: FontWeight.w400,
              ),
            ),
            if (e.detail.isNotEmpty)
              TextSpan(
                text: '   ${e.detail}',
                style: theme.ui(t.textMuted, size: 12),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (e.tooltip.isNotEmpty) {
      label = Tooltip(message: e.tooltip, child: label);
    }
    if (e.submenu case final sub?) {
      return SubmenuButton(menuChildren: _rows(context, sub), child: label);
    }
    final digit = digits && e._pickable && n < 9 ? '${++n}' : '';
    return MenuItemButton(
      onPressed: e.onPick,
      trailingIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            child: e.checked
                ? Icon(Icons.check, size: 14, color: t.text)
                : null,
          ),
          if (digits)
            SizedBox(
              width: 22,
              child: Text(
                digit,
                textAlign: TextAlign.right,
                style: theme.ui(t.textMuted, size: 12),
              ),
            ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.only(right: 12), child: label),
    );
  }

  return [
    for (final e in entries)
      if (identical(e, MenuEntry.divider))
        const Divider(height: 9)
      else if (e.heading)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
          child: Text(e.label, style: theme.ui(t.textMuted, size: 11.5)),
        )
      else
        row(e),
  ];
}
