import 'package:flutter/material.dart';

import 'cards.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// One of a question's options: its [digit], a radio button or, for
/// [many], a check box, its name and description. [at]: ↑/↓ are on it.
class QuestionOption extends StatelessWidget {
  const new(
    this.option, {
    super.key,
    required this.digit,
    required this.many,
    required this.picked,
    required this.at,
    required this.onTap,
  });

  final Option option;
  final String? digit;
  final bool many, picked, at;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Tap(
      onTap: onTap,
      selected: at,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        spacing: 8,
        children: [
          SizedBox(
            width: 12,
            child: digit == null ? null : keyHint(context, digit!),
          ),
          Icon(
            switch ((many, picked)) {
              (false, false) => Icons.radio_button_unchecked,
              (false, true) => Icons.radio_button_checked,
              (true, false) => Icons.check_box_outline_blank,
              (true, true) => Icons.check_box,
            },
            size: 16,
            color: picked ? t.accent : t.textSecondary,
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: option.name,
                style: theme.ui(t.text),
                children: [
                  if (option.description.isNotEmpty)
                    TextSpan(
                      text: '  ${option.description}',
                      style: theme.ui(t.textMuted, size: 12),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A question that is no longer waiting: what was answered.
class AnsweredQuestion extends StatelessWidget {
  const new(this.item, {super.key});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 12);
    final answered = item.fields.where((f) => f.values.isNotEmpty);
    return WaitingCard(
      waiting: false,
      children: [
        CardTitle(item.text, waiting: false),
        if (item.status != 'answered')
          Text(
            item.status == 'declined' ? 'Skipped' : 'Cancelled',
            style: muted,
          )
        else
          for (final f in answered)
            Text.rich(
              TextSpan(
                text: '${f.options.isEmpty ? f.title : f.description}  ',
                style: muted,
                children: [
                  TextSpan(
                    text: f.values
                        .map(
                          (v) =>
                              f.options
                                  .where((o) => o.id == v)
                                  .firstOrNull
                                  ?.name ??
                              v,
                        )
                        .join(', '),
                    style: theme.ui(theme.t.text, size: 12),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
