import 'package:flutter/material.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The agent's config options in the prompt box's row (ADR 0111), without
/// labels, as in Claude Code, each a quiet pill with a ▾: the mode's value
/// (`Auto`), then the model menu (`Opus 5.5  High`): four models, the ones
/// picked last first, then the agent's first (1–4 pick them), Effort ▸,
/// and More models ▸ with the rest; then a "⋯" menu with every option that
/// isn't mode, model or effort (fast mode, agent, Ultracode, ...), and
/// "Ultracode" while that is on. In a narrow row the two values are cut
/// short before anything leaves it.
///
/// [onClose] runs when a menu closes (the composer takes the focus back).
class Pickers extends StatelessWidget {
  const new({
    required this.options,
    required this.onPick,
    super.key,
    this.onClose,
  });

  final List<ConfigOption> options;
  final Future<void> Function(String configId, String value) onPick;
  final VoidCallback? onClose;

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
        for (final v in values ?? o.shownValues) ...[
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
          detail: vs == null ? o.currentName : '',
          submenu: rows(o, values: vs, tips: o == model),
        );

    // Four models: those picked last, the last first, then the agent's
    // first, skipping its "use the default"; the rest (that one included)
    // under More models.
    final models = model == null ? <ConfigValue>[] : model.shownValues;
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
    return Row(
      children: [
        if (mode != null)
          Flexible(
            child: MenuField(
              pill: true,
              tooltip: mode.description.isEmpty ? mode.name : mode.description,
              onClose: onClose,
              entries: rows(mode),
              label: Text(mode.currentName),
            ),
          ),
        if (model != null || effort != null)
          Flexible(
            child: MenuField(
              pill: true,
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
                    if (model != null) TextSpan(text: model.currentName),
                    if (effort != null)
                      TextSpan(
                        text:
                            '${model == null ? '' : '  '}${effort.currentName}',
                        style: theme.ui(t.textMuted, size: 12.5),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (rest.isNotEmpty)
          MenuIcon.line(
            LineIcon.more,
            tooltip: [for (final o in rest) o.name].join(', '),
            onClose: onClose,
            entries: [for (final o in rest) submenu(o.name, o)],
          ),
        if (ultracode?.current == 'true')
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Tooltip(
              message: ultracode!.description,
              child: Text(
                'Ultracode',
                maxLines: 1,
                softWrap: false,
                style: theme.ui(t.accentInk, size: 12.5),
              ),
            ),
          ),
      ],
    );
  }
}

/// What an agent's option and its values are called, wherever they show.
extension ConfigNames on ConfigOption {
  /// Its values as they're picked; a boolean's are On and Off.
  List<ConfigValue> get shownValues => type == 'boolean'
      ? [
          ConfigValue(value: 'true', name: 'On'),
          ConfigValue(value: 'false', name: 'Off'),
        ]
      : values;

  /// [value]'s name, or the value itself when the agent doesn't list it
  /// (a model id set elsewhere).
  String nameOf(String value) =>
      shownValues.where((v) => v.value == value).firstOrNull?.name ?? value;

  /// The current value's name.
  String get currentName => nameOf(current);
}
