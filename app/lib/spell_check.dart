import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show ItemKind;
import 'package:nushi/settings.dart';
import 'package:nushi/spell_scan.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/theme/theme.dart';

/// How long typing pauses before new words go to the checker.
const spellPause = Duration(milliseconds: 250);

/// How much of a prompt is checked: anything longer is a paste, not typing.
const spellLimit = 20000;

/// How much of the agent's latest messages counts as known words.
const _agentText = 200000;

/// [text] up to [spellLimit], not ending in the middle of a word.
String _checked(String text) {
  if (text.length <= spellLimit) return text;
  final end = text.lastIndexOf(RegExp(r'\s'), spellLimit);
  return text.substring(0, end < 0 ? spellLimit : end);
}

/// The prompt box's text, which draws its flagged words with a dotted
/// underline. Flagged words come from the [SpellCheck] on it; a controller
/// because they depend on the caret too, which `TextField`'s own spell check
/// doesn't look at (ADR 0083). With none it builds what any controller does.
class PromptText extends TextEditingController {
  /// The spell check of the box showing this, if one does.
  SpellCheck? spell;

  List<SpellWord> _marks = const [];
  String _markedText = '';

  /// The flagged words, in order. Nothing if the text moved on since they
  /// were set: offsets into other text must never reach a span.
  List<SpellWord> get marks => _markedText == text ? _marks : const [];

  /// Flags [words] of [of], and says whether that's a change.
  bool mark(List<SpellWord> words, String of) {
    if (listEquals(words, marks)) return false;
    _marks = words;
    _markedText = of;
    return true;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    if (marks.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final base = style ?? const TextStyle();
    final flagged = base.copyWith(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: NushiTheme.of(context).t.crashed,
      decorationThickness: 1.5,
    );
    // What an input method is composing stays as Flutter draws it; a flagged
    // word under it waits.
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : null;
    final styled = <(int, int, TextStyle)>[
      for (final m in marks)
        if (composing == null ||
            m.end <= composing.start ||
            m.start >= composing.end)
          (m.start, m.end, flagged),
      if (composing != null)
        (
          composing.start,
          composing.end,
          base.copyWith(decoration: TextDecoration.underline),
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end, spanStyle) in styled) {
      spans
        ..add(TextSpan(text: text.substring(at, start)))
        ..add(TextSpan(text: text.substring(start, end), style: spanStyle));
      at = end;
    }
    spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}

/// Spell check of one prompt box: which of [text]'s words are flagged, kept
/// on it as [PromptText.marks], and notifying when they change. Words go to
/// the [speller] after a pause in typing, each once: the answers are kept by
/// word, so one that comes late is still true, and the marks always come
/// from the text as it is now. A word isn't judged while it's being typed:
/// after typing, the word the caret is in or at the end of waits until the
/// caret moves or leaves it. Off (the [checkSpelling] pref), or without a
/// speller, nothing's asked and nothing's flagged; a failed call leaves its
/// words unflagged, and typing never knows.
class SpellCheck extends ChangeNotifier {
  new(this.text, this.chat, this.focus) {
    text.spell = this;
    text.addListener(_changed);
    checkSpelling.addListener(_changed);
    focus.addListener(_focusChanged);
    _changed();
  }

  final PromptText text;
  final ChatState chat;
  final FocusNode focus;

  final _misspelled = <String, bool>{};
  final _allowed = <String>{}; // ignored or added here, in their known form
  var _agentWords = const <String>{};
  int? _agentRevision;
  List<SpellWord> _words = const [];
  String? _seen; // the text [_words] are of
  TextSelection _selection = const TextSelection.collapsed(offset: -1);
  bool _typing = false;
  Timer? _pause;
  Future<void> _asking = Future.value();
  bool _disposed = false;

  /// Whether spell check runs here now.
  bool get on => speller != null && checkSpelling.value;

  /// The caret, while it's still in the word it typed.
  int? get _typingAt {
    final s = text.selection;
    return _typing && s.isValid && s.isCollapsed ? s.baseOffset : null;
  }

  bool _at(int? caret, SpellWord w) =>
      caret != null && w.start <= caret && caret <= w.end;

  bool _known(String word) {
    final form = knownForm(word);
    return _allowed.contains(form) || _agentWords.contains(form);
  }

  void _changed() {
    if (!on) {
      _pause?.cancel();
      _seen = null;
      _words = const [];
      if (text.mark(const [], '')) notifyListeners();
      return;
    }
    final v = text.value;
    if (v.text != _seen) {
      _typing = _seen != null; // not what the box opened with
      _seen = v.text;
      _words = scanWords(_checked(v.text));
    } else if (v.selection != _selection) {
      _typing = false;
    }
    _selection = v.selection;
    _show();
    _askSoon();
  }

  void _focusChanged() {
    if (focus.hasFocus || !on) return;
    _typing = false;
    _show();
    _askSoon();
  }

  void _show() {
    final caret = _typingAt;
    final flagged = [
      for (final w in _words)
        if (_misspelled[w.word] ?? false)
          if (!_known(w.word) && !_at(caret, w)) w,
    ];
    if (text.mark(flagged, _seen ?? '')) notifyListeners();
  }

  /// The words not judged yet. None during an input method's composing: its
  /// text isn't a word yet, and goes through here once committed. [all]
  /// takes in the one being typed.
  List<String> _unjudged({bool all = false}) {
    if (!text.value.composing.isCollapsed) return const [];
    final caret = all ? null : _typingAt;
    return {
      for (final w in _words)
        if (!_misspelled.containsKey(w.word) &&
            !_known(w.word) &&
            !_at(caret, w))
          w.word,
    }.toList();
  }

  void _askSoon() {
    _pause?.cancel();
    if (_unjudged().isNotEmpty) _pause = Timer(spellPause, _ask);
  }

  /// Asks about the words not judged yet, one call at a time.
  Future<void> _ask({bool all = false}) =>
      _asking = _asking.then((_) => _askNow(all: all));

  Future<void> _askNow({required bool all}) async {
    if (_disposed || !on) return;
    _readAgentWords();
    final words = _unjudged(all: all);
    if (words.isEmpty) return _show();
    try {
      final wrong = (await speller!.misspelled(words)).toSet();
      if (_disposed || !on) return;
      if (_misspelled.length > 2 * spellLimit) _misspelled.clear();
      for (final w in words) {
        _misspelled[w] = wrong.contains(w);
      }
      _show();
    } on Object {
      // Not checked, then. Asked again when the text next changes.
    }
  }

  /// The words of the agent's messages count as known: they cover the
  /// project's own. Read again only when the transcript changed, and from
  /// the latest messages only, so a long chat stays cheap.
  void _readAgentWords() {
    if (_agentRevision == chat.revision) return;
    _agentRevision = chat.revision;
    final messages = <String>[];
    var room = _agentText;
    for (final it in chat.items.reversed) {
      if (room <= 0) break;
      if (it.kind != ItemKind.ITEM_KIND_AGENT_MESSAGE) continue;
      messages.add(it.text);
      room -= it.text.length;
    }
    _agentWords = wordsOf(messages);
  }

  @override
  void dispose() {
    _disposed = true;
    _pause?.cancel();
    text.removeListener(_changed);
    checkSpelling.removeListener(_changed);
    focus.removeListener(_focusChanged);
    if (identical(text.spell, this)) text.spell = null;
    text.mark(const [], '');
    super.dispose();
  }
}
