import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer_code.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show ItemKind;
import 'package:nushi/settings.dart';
import 'package:nushi/spell_menu.dart';
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

/// The composer's text, which draws its flagged words with a dotted
/// underline. Flagged words come from the [SpellCheck] on it; a controller
/// because they depend on the caret too, which `TextField`'s own spell check
/// doesn't look at (ADR 0083). It draws its code in the code font too
/// ([codePaints]). With neither it builds what any controller does.
class ComposerText extends TextEditingController {
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

  List<CodeRun> _code = const [];
  String? _codeText;

  /// The code in the text ([codeRuns]), found again only when it changes.
  List<CodeRun> get code {
    if (_codeText != text) {
      _codeText = text;
      _code = codeRuns(text);
    }
    return _code;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    if (marks.isEmpty && code.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final theme = NushiTheme.of(context);
    final base = style ?? const TextStyle();
    final flagged = TextStyle(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: theme.t.crashed,
      decorationThickness: 1.5,
    );
    // What an input method is composing stays as Flutter draws it; a flagged
    // word under it waits.
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : null;
    return paintedSpan(text, style, [
      codePaints(code, base, theme, selection: selection),
      [
        for (final m in marks)
          if (composing == null ||
              m.end <= composing.start ||
              m.start >= composing.end)
            (m.start, m.end, flagged),
      ],
      if (composing != null)
        [
          (
            composing.start,
            composing.end,
            const TextStyle(decoration: TextDecoration.underline),
          ),
        ],
    ]);
  }
}

/// Spell check of one composer: which of [text]'s words are flagged, kept
/// on it as [ComposerText.marks], and notifying when they change. Words go to
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

  final ComposerText text;
  final ChatState chat;
  final FocusNode focus;

  /// The menu of a flagged word.
  late final menu = SpellMenu(this);

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

  /// Whether a flagged word may be fixed now: not while the box is locked
  /// for a message coming back ([ChatState.rewinding]).
  bool get fixable => on && !chat.rewinding.value;

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
      if (menu.word != null) menu.close();
      _pause?.cancel();
      _seen = null;
      _words = const [];
      if (text.mark(const [], '')) notifyListeners();
      return;
    }
    final v = text.value;
    if (v.text != _seen) {
      if (menu.word != null) menu.close(); // typed, or something put text in
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
  /// text isn't a word yet, and goes through here once committed.
  List<String> _unjudged() {
    if (!text.value.composing.isCollapsed) return const [];
    final caret = _typingAt;
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
  Future<void> _ask() => _asking = _asking.then((_) => _askNow());

  Future<void> _askNow() async {
    if (_disposed || !on) return;
    _readAgentWords();
    final words = _unjudged();
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

  /// Stops treating the caret's word as being typed, and judges every word
  /// there is. For `⌘;`, which can't wait for the pause.
  Future<void> judgeAll() async {
    _pause?.cancel();
    settle();
    await _ask();
  }

  /// Text put in the box whole isn't typing: nothing waits for the caret.
  void settle() {
    _typing = false;
    _show();
  }

  /// Stops flagging [word]: for good if [add], else until the app quits.
  void allow(String word, {required bool add}) {
    _allowed.add(knownForm(word));
    _show();
    unawaited(_tell(word, add: add));
  }

  Future<void> _tell(String word, {required bool add}) async {
    try {
      await (add ? speller?.learn(word) : speller?.ignore(word));
    } on Object {
      // The flag stays gone here; the checker just won't remember.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    menu.dispose();
    _pause?.cancel();
    text.removeListener(_changed);
    checkSpelling.removeListener(_changed);
    focus.removeListener(_focusChanged);
    if (identical(text.spell, this)) text.spell = null;
    text.mark(const [], '');
    super.dispose();
  }
}
