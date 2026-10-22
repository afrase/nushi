import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'markdown.dart';

/// A card for something the agent waits on; outlined in the accent while it waits.
class WaitingCard extends StatelessWidget {
  const WaitingCard({super.key, required this.waiting, required this.children});

  final bool waiting;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: waiting ? scheme.tertiary : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: children,
      ),
    );
  }
}

/// The agent's permission prompt, with its own options as buttons.
class PermissionCard extends StatelessWidget {
  const PermissionCard(this.item, {super.key, required this.onAnswer});

  final Item item;
  final Future<void> Function(String optionId) onAnswer;

  Future<void> _answer(BuildContext context, String optionId) async {
    try {
      await onAnswer(optionId);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = item.status == 'pending';
    final picked = item.options.where((o) => o.id == item.answer).firstOrNull;
    return WaitingCard(
      waiting: pending,
      children: [
        Text(
          pending ? 'The agent asks for permission' : 'Permission',
          style: theme.textTheme.labelMedium,
        ),
        Text(
          item.title,
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
        ),
        if (item.text.isNotEmpty) AgentMarkdown(item.text),
        if (pending)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in item.options)
                o.kind.startsWith('allow')
                    ? FilledButton.tonal(
                        onPressed: () => _answer(context, o.id),
                        child: Text(o.name),
                      )
                    : OutlinedButton(
                        onPressed: () => _answer(context, o.id),
                        child: Text(o.name),
                      ),
            ],
          )
        else
          Text(
            picked != null ? 'Answered: ${picked.name}' : 'Cancelled',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
      ],
    );
  }
}
