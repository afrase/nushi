import 'package:flutter/widgets.dart';
import 'package:nushi/attached_files.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show ImageData;
import 'package:nushi/images.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/run_text.dart';
import 'package:nushi/spell_check.dart';

/// What the user is writing to a chat: the box's text, the files mentioned
/// with @, the reply cards, the images and the attached files, and the
/// boxes for messages to
/// its subagents. It lives on the chat, not in the view, so switching
/// chats, a peek at Changes or the MCP servers, or a lost connection don't
/// lose it; `Drafts` keeps it on disk too. It notifies on any change.
class Draft extends ChangeNotifier {
  new() {
    for (final l in <Listenable>[
      text,
      replies,
      outputs,
      images,
      files,
      quote,
      toSubagent,
    ]) {
      l.addListener(notifyListeners);
    }
  }

  final text = ComposerText();
  final mentions = <String>{};
  final Replies replies = ValueNotifier(const []);
  final images = Attachments();

  /// The files attached as file cards (ADR 0091); [images] counts their
  /// reads too ([Attachments.track]).
  final files = ValueNotifier<List<AttachedFile>>(const []);

  /// Adds [r] as a card, unless it's there already (the same comment,
  /// thread or check sent twice); whether it was added.
  bool addReply(Reply r) {
    final now = replies.value;
    if (now.contains(r)) return false;
    replies.value = [...now, r];
    return true;
  }

  /// The outputs of code block runs that ended, as cards, sent after the
  /// next message's text; not saved.
  final outputs = ValueNotifier<List<RunOutput>>(const []);

  /// Text to quote in the box (a side chat's start), taken by the box.
  final quote = ValueNotifier<String?>(null);

  /// The subagent a message taken back was for: its call and type. The
  /// message goes there again.
  final toSubagent = ValueNotifier<(String call, String agent)?>(null);

  /// The box for a message to the subagent of call [call] (its pane's).
  TextEditingController subagentBox(String call) =>
      _subagents[call] ??= TextEditingController()
        ..addListener(notifyListeners);
  final _subagents = <String, TextEditingController>{};

  /// There's a message to send: text, an image, a file, a reply card or a
  /// run's output in the box (a quote or a subagent's box isn't one).
  bool get hasMessage =>
      text.text.trim().isNotEmpty ||
      images.value.isNotEmpty ||
      files.value.isNotEmpty ||
      replies.value.isNotEmpty ||
      outputs.value.isNotEmpty;

  /// Takes the box's message out to send, leaving the box empty.
  Outgoing take() {
    final m = (
      text: text.text.trim(),
      images: images.value,
      files: files.value,
      replies: replies.value,
      outputs: outputs.value,
      mentions: {...mentions},
      toSubagent: toSubagent.value,
    );
    text.clear();
    images.clear();
    files.value = const [];
    replies.value = const [];
    outputs.value = const [];
    toSubagent.value = null;
    mentions.clear();
    return m;
  }

  /// Puts back [m], taken to send, when it didn't go, before what was
  /// written since: its text first, a blank line after it; its images and
  /// cards in front; its files first, each once; its outputs unless one of
  /// the same run came since; its subagent unless one was picked since.
  void putBack(Outgoing m) {
    final since = text.text.trim();
    text.text = [m.text, if (since.isNotEmpty) since].join('\n\n');
    images.value = [...m.images, ...images.value];
    files.value = [
      ...m.files,
      ...files.value.where((f) => !m.files.contains(f)),
    ];
    replies.value = [...m.replies, ...replies.value];
    outputs.value = [
      ...m.outputs.where((o) => !outputs.value.any((n) => n.key == o.key)),
      ...outputs.value,
    ];
    toSubagent.value ??= m.toSubagent;
    mentions.addAll(m.mentions);
  }

  /// Nothing written: no text, card, image or quote in any box.
  bool get isEmpty =>
      text.text.trim().isEmpty &&
      replies.value.isEmpty &&
      images.value.isEmpty &&
      files.value.isEmpty &&
      quote.value == null &&
      _subagents.values.every((c) => c.text.trim().isEmpty);

  /// The draft as kept: [image] names each image as kept (null: it isn't),
  /// [textOnly] keeps only the boxes' text and the reply cards.
  Map<String, Object?> toJson({
    String? Function(ImageData)? image,
    bool textOnly = false,
  }) {
    final sel = text.selection;
    final subagents = {
      for (final MapEntry(:key, :value) in _subagents.entries)
        if (value.text.trim().isNotEmpty) key: value.text,
    };
    final images = [
      if (!textOnly && image != null)
        for (final i in this.images.value) ?image(i),
    ];
    return {
      if (text.text.isNotEmpty) 'text': text.text,
      if (text.text.isNotEmpty && sel.isValid)
        'cursor': [sel.baseOffset, sel.extentOffset],
      if (replies.value.isNotEmpty)
        'replies': [
          for (final r in replies.value)
            {'quote': r.quote, 'text': r.text, 'from': r.from},
        ],
      if (subagents.isNotEmpty) 'subagents': subagents,
      if (!textOnly) ...{
        if (mentions.isNotEmpty) 'mentions': [...mentions],
        if (images.isNotEmpty) 'images': images,
        // A Mac's files by their paths; the phone's bytes aren't kept.
        if (files.value.where((f) => f.data == null) case final kept
            when kept.isNotEmpty)
          'files': [for (final f in kept) f.path],
        'quote': ?quote.value,
        // Under `relay`, its older name, so drafts on disk still load.
        if (toSubagent.value case (final call, final agent)?)
          'relay': [call, agent],
      },
    };
  }

  /// Puts back what [toJson] kept; [image] gives back each image kept.
  void restore(Map<String, Object?> j, {ImageData? Function(String)? image}) {
    if (j['text'] case final String t) {
      final at = switch (j['cursor']) {
        [final int b, final int e] => (
          b.clamp(0, t.length),
          e.clamp(0, t.length),
        ),
        _ => (t.length, t.length),
      };
      text.value = TextEditingValue(
        text: t,
        selection: TextSelection(baseOffset: at.$1, extentOffset: at.$2),
      );
    }
    if (j['mentions'] case final List<Object?> m) {
      mentions.addAll(m.whereType<String>());
    }
    if (j['replies'] case final List<Object?> rs) {
      replies.value = [
        for (final r in rs.whereType<Map<String, Object?>>())
          if (r case {
            'quote': final String quote,
            'text': final String text,
            'from': final String from,
          })
            (quote: quote, text: text, from: from),
      ];
    }
    if (j['images'] case final List<Object?> names when image != null) {
      images.value = [for (final n in names.whereType<String>()) ?image(n)];
    }
    if (j['files'] case final List<Object?> paths) {
      files.value = [
        for (final p in paths.whereType<String>()) AttachedFile.at(p),
      ];
    }
    if (j['quote'] case final String q) quote.value = q;
    if (j['relay'] case [final String call, final String agent]) {
      toSubagent.value = (call, agent);
    }
    if (j['subagents'] case final Map<String, Object?> s) {
      for (final MapEntry(:key, :value) in s.entries) {
        if (value is String) subagentBox(key).text = value;
      }
    }
  }
}

/// A message taken out of a [Draft] to send, as it was in the box (its
/// text trimmed).
typedef Outgoing = ({
  String text,
  List<ImageData> images,
  List<AttachedFile> files,
  List<Reply> replies,
  List<RunOutput> outputs,
  Set<String> mentions,
  (String call, String agent)? toSubagent,
});

/// An agent's question form half answered (QuestionCard): what's picked
/// and written, and the question it's on. It lives on the chat, so a look
/// at another chat or at Settings doesn't lose it.
final class QuestionDraft {
  /// The options picked, by field id.
  final picked = <String, List<String>>{};

  /// The text written, by field id.
  final text = <String, TextEditingController>{};

  /// The question shown (the last is Submit).
  int tab = 0;
}
