import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'markdown.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// A card for something the agent waits on: amber while it waits.
class WaitingCard extends StatelessWidget {
  const WaitingCard({super.key, required this.waiting, required this.children});

  final bool waiting;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: waiting ? t.needsSoft : null,
        border: Border.all(color: waiting ? t.needs : t.borderSubtle),
        borderRadius: BorderRadius.circular(NushiTheme.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: children,
      ),
    );
  }
}

/// The card's first line: an icon and what it is about.
class CardTitle extends StatelessWidget {
  const CardTitle(
    this.title, {
    super.key,
    this.detail = '',
    this.waiting = true,
  });

  final String title;
  final String detail;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Row(
      children: [
        Icon(
          waiting ? Icons.warning_amber_rounded : Icons.check,
          size: 14,
          color: waiting ? t.needs : t.textMuted,
        ),
        const SizedBox(width: 8),
        Text(title, style: theme.ui(t.text, weight: FontWeight.w600)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            detail,
            overflow: TextOverflow.ellipsis,
            style: theme.code(t.text, size: 12).copyWith(height: 1.3),
          ),
        ),
      ],
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
    final theme = NushiTheme.of(context);
    final pending = item.status == 'pending';
    final picked = item.options.where((o) => o.id == item.answer).firstOrNull;
    return WaitingCard(
      waiting: pending,
      children: [
        CardTitle('Permission', detail: item.title, waiting: pending),
        if (item.text.isNotEmpty) AgentMarkdown(item.text),
        if (pending)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (i, o) in item.options.indexed)
                Button(
                  label: o.name,
                  kind: i == 0 ? ButtonKind.primary : ButtonKind.secondary,
                  onPressed: () => _answer(context, o.id),
                ),
            ],
          )
        else
          Text(
            picked != null ? 'Answered: ${picked.name}' : 'Cancelled',
            style: theme.ui(theme.t.textMuted, size: 12),
          ),
      ],
    );
  }
}
