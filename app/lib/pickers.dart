import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';

/// The agent's config options (mode first, then model, ...) as a row of
/// pickers under the transcript.
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
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final o in sorted)
            o.type == 'boolean'
                ? FilterChip(
                    label: Text(o.name),
                    tooltip: o.description,
                    selected: o.current == 'true',
                    onSelected: (on) => _pick(context, o.id, '$on'),
                  )
                : _Select(o, onPick: (v) => _pick(context, o.id, v)),
        ],
      ),
    );
  }
}

class _Select extends StatelessWidget {
  const _Select(this.option, {required this.onPick});

  final ConfigOption option;
  final void Function(String value) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = option.values
        .where((v) => v.value == option.current)
        .firstOrNull;
    final items = <PopupMenuEntry<String>>[];
    String? group;
    for (final v in option.values) {
      if (v.group.isNotEmpty && v.group != group) {
        group = v.group;
        items.add(
          PopupMenuItem(
            enabled: false,
            height: 28,
            child: Text(group, style: theme.textTheme.labelSmall),
          ),
        );
      }
      items.add(
        CheckedPopupMenuItem(
          value: v.value,
          checked: v.value == option.current,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(v.name),
            subtitle: v.description.isEmpty ? null : Text(v.description),
          ),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: option.description.isEmpty ? option.name : option.description,
      itemBuilder: (_) => items,
      onSelected: onPick,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Text(
              option.name,
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            Text(current?.name ?? option.current),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
