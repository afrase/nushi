import 'package:flutter/material.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The agent's config options under the prompt box, without labels, as in
/// Claude Code: the mode's value on the left (`Auto`); on the right
/// "Ultracode" while that is on, a "⋯" menu with every option that isn't
/// mode, model or effort (fast mode, agent, Ultracode, ...), then the
/// model menu (`Opus 5.5  High`): four models, the ones picked last first,
/// then the agent's first (1–4 pick them), Effort ▸, and More models ▸ with
/// the rest.
///
/// [onClose] runs when a menu closes (the composer takes the focus back).
class Pickers extends StatelessWidget {
  const new({
    required this.options,
    required this.onPick,
    super.key,
    this.onClose,
    this.leading,
  });

  final List<ConfigOption> options;
  final Future<void> Function(String configId, String value) onPick;
  final VoidCallback? onClose;

  /// After the mode, on the left.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    ConfigOption? of(String category) =>
        options.where((o) => o.category == category).firstOrNull;
    final mode = of('mode');
    final model = of('model');
    final effort = of('thought_level');
    final ultracode = of('ultracode');
    final rest = [
      for (final o in options)
        if (o != mode && o != model && o != effort) o,
    ];

    /// [values] of [o] (all of them by default) under their groups' names,
    /// each description on its row, or with [tips] as its tooltip.
    List<MenuEntry> rows(
      ConfigOption o, {
      List<ConfigValue>? values,
      bool tips = false,
    }) {
      String? group;
      return [
        for (final v in values ?? _values(o)) ...[
          if (v.group.isNotEmpty && v.group != group)
            MenuEntry.heading(group = v.group),
          MenuEntry(
            v.name,
            detail: tips ? '' : v.description,
            tooltip: tips ? v.description : '',
            checked: v.value == o.current,
            onPick: () => tryOrShow(context, () async {
              await onPick(o.id, v.value);
              if (o == model) {
                recentModels.value = [
                  v.value,
                  ...recentModels.value.where((r) => r != v.value),
                ].take(20).toList();
              }
            }),
          ),
        ],
      ];
    }

    MenuEntry submenu(String name, ConfigOption o, [List<ConfigValue>? vs]) =>
        MenuEntry(
          name,
          detail: vs == null ? _current(o) : '',
          submenu: rows(o, values: vs, tips: o == model),
        );

    // Four models: those picked last, the last first, then the agent's
    // first, skipping its "use the default"; the rest (that one included)
    // under More models.
    final models = model == null ? <ConfigValue>[] : _values(model);
    final picked = [
      for (final r in recentModels.value)
        ?models.where((v) => v.value == r && !v.isDefault).firstOrNull,
    ];
    final top = [
      ...picked,
      ...models.where((v) => !v.isDefault && !picked.contains(v)),
    ].take(4).toList();
    final more = [
      for (final v in models)
        if (!top.contains(v)) v,
    ];
    final value = theme.ui(t.textSecondary, size: 12);
    return Row(
      children: [
        if (mode != null)
          MenuField(
            compact: true,
            tooltip: mode.description.isEmpty ? mode.name : mode.description,
            onClose: onClose,
            entries: rows(mode),
            label: Text(_current(mode), style: value),
          ),
        if (leading != null) Flexible(child: leading!) else const Spacer(),
        if (leading != null) const SizedBox(width: 12),
        if (ultracode?.current == 'true')
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Tooltip(
              message: ultracode!.description,
              child: Text('Ultracode', style: theme.ui(t.accentInk, size: 12)),
            ),
          ),
        if (rest.isNotEmpty)
          MenuIcon(
            Icons.more_horiz,
            tooltip: [for (final o in rest) o.name].join(', '),
            onClose: onClose,
            entries: [for (final o in rest) submenu(o.name, o)],
          ),
        if (model != null || effort != null)
          MenuField(
            compact: true,
            tooltip: [?model?.name, ?effort?.name].join(', '),
            onClose: onClose,
            digits: true,
            entries: [
              if (model != null) ...rows(model, values: top, tips: true),
              if (model != null && effort != null) MenuEntry.divider,
              if (effort != null) submenu('Effort', effort),
              if (model != null && more.isNotEmpty)
                submenu('More models', model, more),
            ],
            label: Text.rich(
              TextSpan(
                children: [
                  if (model != null) TextSpan(text: _current(model)),
                  if (effort != null)
                    TextSpan(
                      text: '${model == null ? '' : '  '}${_current(effort)}',
                      style: theme.ui(t.textMuted, size: 12),
                    ),
                ],
              ),
              style: value,
            ),
          ),
      ],
    );
  }
}

/// An option's values; booleans are On and Off.
List<ConfigValue> _values(ConfigOption o) => o.type == 'boolean'
    ? [
        ConfigValue(value: 'true', name: 'On'),
        ConfigValue(value: 'false', name: 'Off'),
      ]
    : o.values;

/// The name of an option's current value.
String _current(ConfigOption o) =>
    _values(o).where((v) => v.value == o.current).firstOrNull?.name ??
    o.current;
