import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';

/// The agent's config options under the prompt box, without labels: the
/// mode's value on the left (`Auto`), and on the right one menu for the
/// model and effort (`Opus 5.5  High`), with every other option (fast mode,
/// agent, ...) below them in the same menu.
class Pickers extends StatelessWidget {
  const Pickers({
    super.key,
    required this.options,
    required this.onPick,
    this.trailing,
  });

  final List<ConfigOption> options;
  final Future<void> Function(String configId, String value) onPick;

  /// After the model menu, at the far right (the context ring).
  final Widget? trailing;

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
    final main = [?model, ?effort];
    List<Widget> values(ConfigOption o) =>
        _values(context, o, (v) => _pick(context, o.id, v));
    return Row(
      children: [
        if (mode != null)
          _Menu(
            tooltip: mode.description.isEmpty ? mode.name : mode.description,
            label: Text(
              _current(mode),
              style: theme.ui(t.textSecondary, size: 12),
            ),
            children: values(mode),
          ),
        const Spacer(),
        if (main.isNotEmpty || rest.isNotEmpty)
          _Menu(
            tooltip: [
              for (final o in [...main, ...rest]) o.name,
            ].join(', '),
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
                  if (main.isEmpty)
                    TextSpan(
                      text: 'Options',
                      style: theme.ui(t.textSecondary, size: 12),
                    ),
                ],
              ),
            ),
            children: [
              for (final (i, o) in main.indexed) ...[
                if (i > 0) const Divider(height: 9),
                _heading(theme, o.name),
                ...values(o),
              ],
              if (main.isNotEmpty && rest.isNotEmpty) const Divider(height: 9),
              for (final o in rest)
                SubmenuButton(
                  menuChildren: values(o),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: o.name, style: theme.ui(t.text)),
                        TextSpan(
                          text: '   ${_current(o)}',
                          style: theme.ui(t.textMuted, size: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ?trailing,
      ],
    );
  }
}

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

Widget _heading(NushiTheme theme, String text) => Padding(
  padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
  child: Text(text, style: theme.ui(theme.t.textMuted, size: 11.5)),
);

/// An option's values as menu items, the current one checked, under their
/// groups' names.
List<Widget> _values(
  BuildContext context,
  ConfigOption o,
  void Function(String value) onPick,
) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  final out = <Widget>[];
  String? group;
  for (final v in _options(o)) {
    if (v.group.isNotEmpty && v.group != group) {
      group = v.group;
      out.add(_heading(theme, group));
    }
    out.add(
      MenuItemButton(
        onPressed: () => onPick(v.value),
        style: MenuItemButton.styleFrom(
          minimumSize: const Size(0, 28),
          visualDensity: VisualDensity.compact,
        ),
        leadingIcon: SizedBox(
          width: 14,
          child: v.value == o.current
              ? Icon(Icons.check, size: 14, color: t.text)
              : null,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: v.name, style: theme.ui(t.text)),
                if (v.description.isNotEmpty)
                  TextSpan(
                    text: '  ${v.description}',
                    style: theme.ui(t.textMuted, size: 12),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
  return out;
}

/// A quiet text button that opens a menu.
class _Menu extends StatelessWidget {
  const _Menu({
    required this.tooltip,
    required this.label,
    required this.children,
  });

  final String tooltip;
  final Widget label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return MenuAnchor(
      menuChildren: children,
      builder: (context, controller, _) => Tooltip(
        message: tooltip,
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
          child: label,
        ),
      ),
    );
  }
}
