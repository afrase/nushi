import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';

/// The agent's config options under the prompt box, without labels, as in
/// Claude Code: the mode's value on the left (`Auto`); on the right a "⋯"
/// menu with every option that isn't mode, model or effort (fast mode,
/// agent, ...), then the model menu (`Opus 5.5  High`): the agent's first
/// four models (1–4 pick them), Effort ▸, and More models ▸ with the rest.
///
/// [onClose] runs when a menu closes (the composer takes the focus back).
class Pickers extends StatelessWidget {
  const Pickers({
    super.key,
    required this.options,
    required this.onPick,
    this.onClose,
  });

  final List<ConfigOption> options;
  final Future<void> Function(String configId, String value) onPick;
  final VoidCallback? onClose;

  Future<void> _pick(BuildContext context, String id, String value) async {
    try {
      await onPick(id, value);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    ConfigOption? of(String category) =>
        options.where((o) => o.category == category).firstOrNull;
    final mode = of('mode');
    final model = of('model');
    final effort = of('thought_level');
    final rest = [
      for (final o in options)
        if (o != mode && o != model && o != effort) o,
    ];
    void Function(String) pick(ConfigOption o) =>
        (v) => _pick(context, o.id, v);

    // The first four models by name, skipping a "Default" entry; the rest
    // (that one included) under More models.
    final models = model == null ? <ConfigValue>[] : _options(model);
    final top = models
        .where((v) => !v.name.toLowerCase().startsWith('default'))
        .take(4)
        .toList();
    final more = [
      for (final v in models)
        if (!top.contains(v)) v,
    ];
    Widget submenu(
      String name,
      ConfigOption o,
      List<ConfigValue> values, {
      bool showCurrent = true,
    }) => SubmenuButton(
      menuChildren: _values(
        context,
        o,
        values,
        pick(o),
        descriptions: o != model,
      ),
      style: _itemStyle,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: name,
              style: theme.ui(t.text, weight: FontWeight.w400),
            ),
            if (showCurrent)
              TextSpan(
                text: '   ${_current(o)}',
                style: theme.ui(t.textMuted, size: 12),
              ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        if (mode != null)
          _Menu(
            tooltip: mode.description.isEmpty ? mode.name : mode.description,
            label: Text(
              _current(mode),
              style: theme.ui(t.textSecondary, size: 12),
            ),
            onClose: onClose,
            children: _values(context, mode, _options(mode), pick(mode)),
          ),
        const Spacer(),
        if (rest.isNotEmpty)
          _Menu(
            tooltip: [for (final o in rest) o.name].join(', '),
            label: Icon(Icons.more_horiz, size: 16, color: t.textSecondary),
            onClose: onClose,
            children: [for (final o in rest) submenu(o.name, o, _options(o))],
          ),
        if (model != null || effort != null)
          _Menu(
            tooltip: [?model?.name, ?effort?.name].join(', '),
            label: Text.rich(
              TextSpan(
                children: [
                  if (model != null)
                    TextSpan(
                      text: _current(model),
                      style: theme.ui(t.textSecondary, size: 12),
                    ),
                  if (effort != null)
                    TextSpan(
                      text: '${model == null ? '' : '  '}${_current(effort)}',
                      style: theme.ui(t.textMuted, size: 12),
                    ),
                ],
              ),
            ),
            onClose: onClose,
            digits: model == null
                ? const []
                : [for (final v in top) () => pick(model)(v.value)],
            children: [
              if (model != null)
                ..._values(
                  context,
                  model,
                  top,
                  pick(model),
                  digits: true,
                  descriptions: false,
                ),
              if (model != null && effort != null) const Divider(height: 9),
              if (effort != null) submenu('Effort', effort, _options(effort)),
              if (model != null && more.isNotEmpty)
                submenu('More models', model, more, showCurrent: false),
            ],
          ),
      ],
    );
  }
}

final _itemStyle = MenuItemButton.styleFrom(
  minimumSize: const Size(0, 28),
  visualDensity: VisualDensity.compact,
);

/// An option's values; booleans are On and Off.
List<ConfigValue> _options(ConfigOption o) => o.type == 'boolean'
    ? [
        ConfigValue(value: 'true', name: 'On'),
        ConfigValue(value: 'false', name: 'Off'),
      ]
    : o.values;

/// The name of an option's current value.
String _current(ConfigOption o) =>
    _options(o).where((v) => v.value == o.current).firstOrNull?.name ??
    o.current;

/// [values] of option [o] as menu items under their groups' names: the
/// name on one line, then the description, dimmed and cut off (or, without
/// [descriptions], as a tooltip); on the right a check on the current one
/// and, with [digits], 1, 2, ... as the keys that pick them.
List<Widget> _values(
  BuildContext context,
  ConfigOption o,
  List<ConfigValue> values,
  void Function(String value) onPick, {
  bool digits = false,
  bool descriptions = true,
}) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  final out = <Widget>[];
  String? group;
  for (final (i, v) in values.indexed) {
    if (v.group.isNotEmpty && v.group != group) {
      group = v.group;
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Text(group, style: theme.ui(t.textMuted, size: 11.5)),
        ),
      );
    }
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: v.name,
            style: theme.ui(t.text, weight: FontWeight.w400),
          ),
          if (descriptions && v.description.isNotEmpty)
            TextSpan(
              text: '   ${v.description}',
              style: theme.ui(t.textMuted, size: 12),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    out.add(
      MenuItemButton(
        onPressed: () => onPick(v.value),
        style: _itemStyle,
        trailingIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              child: v.value == o.current
                  ? Icon(Icons.check, size: 14, color: t.text)
                  : null,
            ),
            if (digits)
              SizedBox(
                width: 22,
                child: Text(
                  '${i + 1}',
                  textAlign: TextAlign.right,
                  style: theme.ui(t.textMuted, size: 12),
                ),
              ),
          ],
        ),
        child: !descriptions
            ? Tooltip(
                message: v.description,
                waitDuration: const Duration(milliseconds: 600),
                child: Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: text,
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: text,
                ),
              ),
      ),
    );
  }
  return out;
}

/// A quiet button that opens a menu. While it is open, the digit keys run
/// [digits] (1 the first) and close it. [onClose] runs once it has closed.
class _Menu extends StatefulWidget {
  const _Menu({
    required this.tooltip,
    required this.label,
    required this.children,
    this.digits = const [],
    this.onClose,
  });

  final String tooltip;
  final Widget label;
  final List<Widget> children;
  final List<VoidCallback> digits;
  final VoidCallback? onClose;

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  final _menu = MenuController();
  final _focus = FocusNode(debugLabel: 'menu button');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, e) {
        final i = _digits.indexOf(e.logicalKey);
        if (e is! KeyDownEvent || i < 0 || i >= widget.digits.length) {
          return KeyEventResult.ignored;
        }
        widget.digits[i]();
        _menu.close();
        return KeyEventResult.handled;
      },
      child: MenuAnchor(
        controller: _menu,
        menuChildren: widget.children,
        onOpen: () {
          if (widget.digits.isNotEmpty) _focus.requestFocus();
        },
        // After the menu has settled its own focus.
        onClose: () => WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onClose?.call(),
        ),
        builder: (context, controller, _) => Tooltip(
          message: widget.tooltip,
          waitDuration: const Duration(milliseconds: 500),
          child: TextButton(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 22)),
              fixedSize: const WidgetStatePropertyAll(Size.fromHeight(22)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 6),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              overlayColor: WidgetStatePropertyAll(
                t.text.withValues(alpha: 0.06),
              ),
              shape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(NushiTheme.control),
                  ),
                ),
              ),
            ),
            child: widget.label,
          ),
        ),
      ),
    );
  }
}

const _digits = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
];
