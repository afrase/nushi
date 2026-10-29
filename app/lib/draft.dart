import 'package:flutter/widgets.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show ImageData;
import 'package:nushi/images.dart';
import 'package:nushi/replies.dart';

/// What the user is writing to a chat: the box's text, the files mentioned
/// with @, the reply cards and the images, and the boxes for messages to
/// its subagents. It lives on the chat, not in the view, so switching
/// chats, a peek at Changes or the MCP servers, or a lost connection don't
/// lose it; `Drafts` keeps it on disk too. It notifies on any change.
class Draft extends ChangeNotifier {
  new() {
    for (final l in <Listenable>[text, replies, images, quote, relay]) {
      l.addListener(notifyListeners);
    }
  }

  final text = TextEditingController();
  final mentions = <String>{};
  final Replies replies = ValueNotifier(const []);
  final images = Attachments();

  /// Adds [r] as a card, unless it's there already (the same comment,
  /// thread or check sent twice).
  void addReply(Reply r) {
    final now = replies.value;
    if (now.contains(r)) return;
    replies.value = [...now, r];
  }

  /// Text to quote in the box (a side question's start), taken by the box.
  final quote = ValueNotifier<String?>(null);

  /// The subagent a message taken back was for: its call and type. The
  /// message goes there again.
  final relay = ValueNotifier<(String call, String agent)?>(null);

  /// The box for a message to the subagent of call [call] (its pane's).
  TextEditingController subagentBox(String call) =>
      _subagents[call] ??= TextEditingController()
        ..addListener(notifyListeners);
  final _subagents = <String, TextEditingController>{};

  /// Nothing written: no text, card, image or quote in any box.
  bool get isEmpty =>
      text.text.trim().isEmpty &&
      replies.value.isEmpty &&
      images.value.isEmpty &&
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
        'quote': ?quote.value,
        if (relay.value case (final call, final agent)?) 'relay': [call, agent],
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
    if (j['quote'] case final String q) quote.value = q;
    if (j['relay'] case [final String call, final String agent]) {
      relay.value = (call, agent);
    }
    if (j['subagents'] case final Map<String, Object?> s) {
      for (final MapEntry(:key, :value) in s.entries) {
        if (value is String) subagentBox(key).text = value;
      }
    }
  }
}

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
