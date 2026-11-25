import 'package:flutter/material.dart';

import 'package:nushi/cards.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// One question of a form: a field with options, or a text field, and the
/// free-text "Other" field the daemon pairs with it, if any.
typedef AskedQuestion = ({Field field, Field? other});

/// A form's [fields] as its questions, each "Other" field beside the one
/// it answers.
List<AskedQuestion> askedQuestions(List<Field> fields) {
  final out = <AskedQuestion>[];
  for (final f in fields) {
    if (f.otherFor.isNotEmpty && out.lastOrNull?.field.id == f.otherFor) {
      out.last = (field: out.last.field, other: f);
    } else {
      out.add((field: f, other: null));
    }
  }
  return out;
}

/// One of a question's options: its [digit], a radio button or, for
/// [many], a check box, its name and description. [at]: ↑/↓ are on it.
/// Without [onTap] it's an answered question's, read-only: no digit, no
/// row to press, and its name muted unless [picked]; [said] is what was
/// typed for it (an "Other" answer), after its name, and [note] the note
/// on it, a line under it in the secondary colour.
class QuestionOption extends StatelessWidget {
  const new(
    this.option, {
    required this.many,
    required this.picked,
    required this.onTap,
    super.key,
    this.digit,
    this.at = false,
    this.said = '',
    this.note = '',
  });

  final Option option;
  final String? digit;
  final bool many;
  final bool picked;
  final bool at;
  final VoidCallback? onTap;
  final String said;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final readOnly = onTap == null;
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 4);
    final row = Row(
      spacing: 8,
      crossAxisAlignment: readOnly
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        // A phone has no keys: no digit, nor its place; nor a read-only row.
        if (!readOnly && !TouchTargets.of(context))
          SizedBox(
            width: 12,
            child: digit == null ? null : keyHint(context, digit!),
          ),
        // A read-only row may wrap: its mark stays by its first line.
        Padding(
          padding: EdgeInsets.only(top: readOnly ? _markTop(context) : 0),
          child: Icon(
            switch ((many, picked)) {
              (false, false) => Icons.radio_button_unchecked,
              (false, true) => Icons.radio_button_checked,
              (true, false) => Icons.check_box_outline_blank,
              (true, true) => Icons.check_box,
            },
            size: 16,
            color: picked ? t.accentInk : t.textSecondary,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: option.name,
                  style: theme.ui(readOnly && !picked ? t.textMuted : t.text),
                  children: [
                    if (said.isNotEmpty)
                      TextSpan(text: '  $said', style: theme.ui(t.text)),
                    if (option.description.isNotEmpty)
                      TextSpan(
                        text: '  ${option.description}',
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                  ],
                ),
              ),
              // Under the option it's on, so it reads as the pick's.
              if (note.isNotEmpty)
                Text.rich(TextSpan(children: noteSpans(theme, note))),
            ],
          ),
        ),
      ],
    );
    // Read-only, nothing to press: no tint, no hand, no focus.
    if (readOnly) return Padding(padding: padding, child: row);
    return Tap(onTap: onTap, selected: at, padding: padding, child: row);
  }

  /// How far down a 16-point mark sits to centre on the first line.
  static double _markTop(BuildContext context) {
    final style = NushiTheme.of(context).ui(NushiTheme.of(context).t.text);
    return (MediaQuery.textScalerOf(context).scale(style.fontSize!) *
                style.height! -
            16) /
        2;
  }
}

/// An answered question's lines: its title, and each answer, or that it
/// was skipped or cancelled.
List<Widget> answeredLines(BuildContext context, Item item) => [
  CardTitle(item.text, waiting: false),
  ...answerSummary(context, item),
];

/// [note] labelled as the note on a pick: "Note:" muted, then the note in
/// the secondary colour, so it reads neither as one more answer nor as
/// the option's description.
List<InlineSpan> noteSpans(NushiTheme theme, String note, {double size = 13}) =>
    [
      TextSpan(
        text: 'Note: ',
        style: theme.ui(theme.t.textMuted, size: size),
      ),
      TextSpan(
        text: note,
        style: theme.ui(theme.t.textSecondary, size: size),
      ),
    ];

/// The note on [q]'s pick, or '': its "Other" text where the agent read
/// it as one (Field.note) and an option was picked.
String answeredNote(AskedQuestion q) =>
    (q.other?.note ?? false) && q.field.values.isNotEmpty
    ? q.other!.values.join(', ')
    : '';

/// The lines under an answered question's title: each answer, or that it
/// was skipped or cancelled. A note on a pick follows it, in the
/// secondary colour, rather than standing as an answer of its own.
List<Widget> answerSummary(BuildContext context, Item item) {
  final theme = NushiTheme.of(context);
  final muted = theme.ui(theme.t.textMuted, size: 12);
  if (item.status != 'answered') {
    return [
      Text(item.status == 'declined' ? 'Skipped' : 'Cancelled', style: muted),
    ];
  }
  Widget line(Field f, String note) => Text.rich(
    TextSpan(
      text: '${f.options.isEmpty ? f.title : f.description}  ',
      style: muted,
      children: [
        TextSpan(
          text: f.values
              .map(
                (v) => f.options.where((o) => o.id == v).firstOrNull?.name ?? v,
              )
              .join(', '),
          style: theme.ui(theme.t.text, size: 12),
        ),
        if (note.isNotEmpty) ...[
          TextSpan(text: '  ', style: muted),
          ...noteSpans(theme, note, size: 12),
        ],
      ],
    ),
  );
  return [
    for (final q in askedQuestions(item.fields))
      if (answeredNote(q) case final note when note.isNotEmpty)
        line(q.field, note)
      else
        for (final f in [q.field, ?q.other])
          if (f.values.isNotEmpty) line(f, ''),
  ];
}
