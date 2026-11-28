import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/question_parts.dart';

/// What a waiting question card holds, read as the agent will get it: the
/// [draft]'s picks and text over the item's [fields], and which box is a
/// note on a pick, one more answer, or the answer in a pick's place.
final class QuestionForm {
  new(this.fields, this.draft) : questions = askedQuestions(fields);

  final List<Field> fields;
  final QuestionDraft draft;

  /// The fields as questions, each "Other" box beside the one it answers.
  final List<AskedQuestion> questions;

  /// The options picked for [q], by id.
  List<String> picks(AskedQuestion q) => draft.picked[q.field.id] ?? const [];

  /// Whether an option of [q] is picked.
  bool picked(AskedQuestion q) => picks(q).isNotEmpty;

  /// What's typed in [f]'s box, trimmed.
  String typed(Field f) => draft.text[f.id]?.text.trim() ?? '';

  /// Whether [q]'s "Other" box holds text (none without one).
  bool written(AskedQuestion q) =>
      q.other != null && typed(q.other!).isNotEmpty;

  /// The answers as sent: each field's picks, else its text.
  List<FieldAnswer> get answer => [
    for (final f in fields.where((f) => !dropped(f)))
      if (draft.picked[f.id]?.isNotEmpty ?? false)
        FieldAnswer(fieldId: f.id, values: draft.picked[f.id])
      else if (typed(f).isNotEmpty)
        FieldAnswer(fieldId: f.id, values: [typed(f)]),
  ];

  /// The answer to [q] in words, or ''.
  String said(AskedQuestion q) => [
    answered(q).answer,
    answered(q).note,
  ].where((s) => s.isNotEmpty).join(', ');

  /// The answer to [q] in words and the note on its pick, each or ''.
  /// The box's text is a note where the agent reads it so (Field.note)
  /// and an option is picked; otherwise it's one more answer.
  ({String answer, String note}) answered(AskedQuestion q) {
    final names = [
      for (final id in picks(q))
        q.field.options.firstWhere((o) => o.id == id).name,
    ];
    final note = notes(q) ? typed(q.other!) : '';
    final other = note.isEmpty && !dropped(q.other) ? q.other : null;
    return (
      answer: [
        ...names,
        for (final f in [q.field, ?other])
          if (typed(f) case final s when s.isNotEmpty) s,
      ].join(', '),
      note: note,
    );
  }

  /// Whether [q]'s box holds a note on its pick: the agent reads it so
  /// and an option is picked.
  bool notes(AskedQuestion q) => (q.other?.note ?? false) && picked(q);

  /// Whether the agent takes [q]'s box's text in place of its pick
  /// (Field.replaces): a pick or the text, never both.
  bool replaces(AskedQuestion q) => q.other?.replaces ?? false;

  /// Whether [f] is a box whose text an option picked keeps out of the
  /// answer (Field.replaces): kept and greyed, not sent.
  bool dropped(Field? f) =>
      f != null &&
      f.replaces &&
      (draft.picked[f.otherFor]?.isNotEmpty ?? false) &&
      typed(f).isNotEmpty;

  /// Whether [q]'s pick is quoted in a bar under its box: it has a box
  /// whose text goes along with the pick (not in its place).
  bool quotes(AskedQuestion q) => q.other != null && !replaces(q);

  /// Whether [q]'s options stand back: nothing picked and the box's text
  /// is the answer itself.
  bool dims(AskedQuestion q) => !picked(q) && written(q);

  /// Whether [now] is [was] with one run of it deleted, nothing typed.
  static bool deleted(String was, String now) {
    if (now.length >= was.length) return false;
    var head = 0;
    while (head < now.length && now[head] == was[head]) {
      head++;
    }
    return was.endsWith(now.substring(head));
  }
}
