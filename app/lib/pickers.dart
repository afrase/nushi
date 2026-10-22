import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';

/// The agent's config options (mode first, then model, ...) as a row of
/// compact pickers (`Mode: Auto ▾`).
class Pickers extends StatelessWidget {
  const Pickers({super.key, required this.options, required this.onPick});

  final List<ConfigOption> options;
  final Future<void> Function(String configId, String value) onPick;

  static const _order = ['mode', 'model', 'thought_level', 'model_config'];

  int _rank(ConfigOption o) {
    final i = _order.indexOf(o.category);
    return i < 0 ? _order.length : i;
  }

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
    final sorted = [...options]..sort((a, b) => _rank(a) - _rank(b));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in sorted)
          _Picker(o, onPick: (v) => _pick(context, o.id, v)),
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker(this.option, {required this.onPick});

  final ConfigOption option;
  final void Function(String value) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final values = option.type == 'boolean'
        ? [
            ConfigValue(value: 'true', name: 'On'),
            ConfigValue(value: 'false', name: 'Off'),
          ]
        : option.values;
    final current = values.where((v) => v.value == option.current).firstOrNull;
    final children = <Widget>[];
    String? group;
    for (final v in values) {
      if (v.group.isNotEmpty && v.group != group) {
        group = v.group;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Text(group, style: theme.ui(t.textMuted, size: 11.5)),
          ),
        );
      }
      children.add(
        MenuItemButton(
          onPressed: () => onPick(v.value),
          leadingIcon: SizedBox(
            width: 14,
            child: v.value == option.current
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
    return MenuAnchor(
      menuChildren: children,
      builder: (context, controller, _) => Tooltip(
        message: option.description.isEmpty ? option.name : option.description,
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
          child: Text(
            '${option.name}: ${current?.name ?? option.current} ▾',
            style: theme.ui(t.textSecondary, size: 12),
          ),
        ),
      ),
    );
  }
}
