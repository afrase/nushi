import 'package:flutter/material.dart';

import 'package:nushi/cards.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/question_parts.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// How far the header's tint reaches past its words, taken from the card's
/// padding ([AnsweredQuestion.padding]) so the words stay where they were.
const _bleed = EdgeInsets.symmetric(horizontal: 6, vertical: 4);

/// An answered question's card, closed as its answered lines, that opens on
/// its header (a click, or Enter or Space on it) to every question in full
/// and every option it offered, in order: the ones chosen marked as the
/// pending card marks them ([QuestionOption]), the rest muted, an "Other"
/// answer as typed. Read-only: nothing in it answers again. Open or not is
/// the card's own, not kept. Its chevron stays at the header's end.
class AnsweredQuestion extends StatefulWidget {
  const new(this.item, {super.key});

  final Item item;

  /// Whether [item] has more to show open than its lines: an option it
  /// offered. One without options (a text field's, or a copy that kept
  /// none) stays as its lines.
  static bool opens(Item item) => item.fields.any((f) => f.options.isNotEmpty);

  /// The card's padding around it: its header's tint and its body take the
  /// rest of a card's own ([SettleCard.inset]).
  static EdgeInsets get padding => SettleCard.inset - _bleed;

  @override
  State<AnsweredQuestion> createState() => _AnsweredQuestionState();
}

class _AnsweredQuestionState extends State<AnsweredQuestion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final item = widget.item;
    final answered = item.status == 'answered';
    final summary = answerSummary(context, item);
    // The chevron centred on the title's first line, as its icon is.
    final title = theme.ui(t.text, weight: FontWeight.w600);
    final top =
        (MediaQuery.textScalerOf(context).scale(title.fontSize!) *
                title.height! -
            14) /
        2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tap(
          onTap: () => setState(() => _open = !_open),
          padding: _bleed,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: CardTitle(item.text, waiting: false)),
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(top: top),
                child: TurnChevron(open: _open, color: t.textSecondary),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(_bleed.left, 4, _bleed.right, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // "Skipped" stays; the answers give way to the questions.
              if (!answered)
                ...summary
              else
                Disclosure(
                  open: !_open,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: summary,
                  ),
                ),
              Disclosure(
                open: _open,
                child: Padding(
                  padding: EdgeInsets.only(top: answered ? 0 : 10),
                  child: _questions(theme),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _questions(NushiTheme theme) {
    final qs = askedQuestions(widget.item.fields);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        for (final q in qs) _question(theme, q, header: qs.length > 1),
      ],
    );
  }

  /// [q] in full: its header (when [header]), its text, and each option it
  /// offered, those chosen marked.
  Widget _question(NushiTheme theme, AskedQuestion q, {required bool header}) {
    final t = theme.t;
    final f = q.field;
    final many = f.type == FieldType.FIELD_TYPE_CHOICES;
    final about = f.description.isEmpty ? f.title : f.description;
    // What was typed into the field itself, not one of its options.
    final typed = [
      for (final v in f.values)
        if (!f.options.any((o) => o.id == v)) v,
    ];
    // A note on the pick follows the last option picked, not Other.
    final note = answeredNote(q);
    final last = f.options.lastWhere(
      (o) => f.values.contains(o.id),
      orElse: Option.new,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        if (header && f.title.isNotEmpty && f.title != about)
          Text(
            f.title,
            style: theme.ui(t.textMuted, size: 11.5, weight: FontWeight.w600),
          ),
        if (about.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(about, style: theme.ui(t.text)),
          ),
        for (final o in f.options)
          QuestionOption(
            o,
            many: many,
            picked: f.values.contains(o.id),
            note: identical(o, last) ? note : '',
            onTap: null,
          ),
        if (f.options.isEmpty)
          for (final v in typed)
            Padding(
              padding: _bleed,
              child: Text(v, style: theme.ui(t.text)),
            )
        else
          for (final v in typed)
            QuestionOption(
              Option(name: v),
              many: many,
              picked: true,
              onTap: null,
            ),
        if (q.other case final other?)
          QuestionOption(
            Option(name: other.title.isEmpty ? 'Other' : other.title),
            many: many,
            picked: note.isEmpty && other.values.isNotEmpty,
            said: note.isEmpty ? other.values.join(', ') : '',
            onTap: null,
          ),
      ],
    );
  }
}
