import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/theme.dart';
import 'widgets.dart';

/// One row of a [Menu]: [label], then [detail] dimmed on the same line, and
/// a check on the right when [checked]. Picking it runs [onPick]; with
/// [submenu] it opens those rows beside it instead. Without either it
/// shows unavailable. [tooltip] shows on hover.
class MenuEntry {
  const new(
    this.label, {
    this.detail = '',
    this.checked = false,
    this.onPick,
    this.submenu,
    this.tooltip = '',
  }) : heading = false;

  /// A group's name over its rows.
  const new heading(this.label)
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
  const new({
    required this.entries,
    super.key,
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
      menuChildren: _rows(
        context,
        widget.entries,
        _menu.close,
        digits: widget.digits,
      ),
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

/// Lists longer than this get a filter field.
const _filterPast = 10;

List<Widget> _rows(
  BuildContext context,
  List<MenuEntry> entries,
  VoidCallback close, {
  bool digits = false,
}) {
  if (entries.where((e) => e._pickable).length > _filterPast) {
    return [_Filtered(entries, close)];
  }
  final theme = NushiTheme.of(context), t = theme.t;
  var n = 0;
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
        _row(
          context,
          e,
          close,
          digit: !digits
              ? null
              : e._pickable && n < 9
              ? '${++n}'
              : '',
        ),
  ];
}

/// A row: [digit] shows its key on the right; [lit] marks it as the one
/// Enter picks.
Widget _row(
  BuildContext context,
  MenuEntry e,
  VoidCallback close, {
  String? digit,
  bool lit = false,
  Key? key,
}) {
  final theme = NushiTheme.of(context), t = theme.t;
  final on = e.onPick != null || e.submenu != null;
  Widget label = ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 380),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: e.label,
            style: theme.ui(on ? t.text : t.textMuted, weight: FontWeight.w400),
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
  if (e.tooltip.isNotEmpty) label = Tooltip(message: e.tooltip, child: label);
  if (e.submenu case final sub?) {
    return SubmenuButton(
      key: key,
      menuChildren: _rows(context, sub, close),
      child: label,
    );
  }
  return MenuItemButton(
    key: key,
    onPressed: e.onPick,
    style: lit ? MenuItemButton.styleFrom(backgroundColor: t.hover) : null,
    trailingIcon: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          child: e.checked ? Icon(Icons.check, size: 14, color: t.text) : null,
        ),
        if (digit != null)
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
    final theme = NushiTheme.of(context), t = theme.t;
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
