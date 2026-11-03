/// A word of the prompt that spell check looks at, and where it is in it.
typedef SpellWord = ({int start, int end, String word});

/// Code in backticks or fences, closed or not.
final _code = RegExp(r'```[\s\S]*?(```|$)|`[^`\n]*`?');

/// What might be a word: anything between spaces and punctuation that never
/// sits inside one.
final _chunk = RegExp(r'[^\s,;!?()"\[\]{}<>]+');

/// A path, a flag, a mention, a variable or a URL.
final _notProse = RegExp(r'^[/@#~$\-]|://');

/// Punctuation at a word's ends. Digits stay, so `sha256` and `2nd` count as
/// having digits, not as `sha` and `nd`.
final _leading = RegExp('^[^A-Za-z0-9]+');
final _trailing = RegExp(r'[^A-Za-z0-9]+$');
final _notWord = RegExp(r"[^A-Za-z'’\-]");
final _capital = RegExp('[A-Z]');
final _agentWord = RegExp("[A-Za-z][A-Za-z'’]*");

/// The words of [text] worth checking, in order: not code, paths, flags,
/// mentions, names or anything else that isn't prose. A prompt is full of
/// those, and a flag on one is noise, so all that's left alone: words with
/// digits, dots, underscores or colons inside, camelCase and ALLCAPS, words
/// under three letters, and capitalized words mid-sentence, which are
/// probably names. A hyphenated word counts part by part.
List<SpellWord> scanWords(String text) {
  final code = _code.allMatches(text).toList();
  final words = <SpellWord>[];
  var block = 0; // both are in the text's order, so one pass through each
  for (final m in _chunk.allMatches(text)) {
    while (block < code.length && code[block].end <= m.start) {
      block++;
    }
    if (block < code.length && code[block].start < m.end) continue;
    final chunk = m[0]!;
    if (_notProse.hasMatch(chunk)) continue;
    final kept = chunk.replaceFirst(_leading, '');
    final trimmed = kept.replaceFirst(_trailing, '');
    if (trimmed.isEmpty || _notWord.hasMatch(trimmed)) continue;
    var from = m.start + chunk.length - kept.length;
    for (final part in trimmed.split('-')) {
      final start = from;
      from += part.length + 1;
      if (part.length < 3 || _capital.hasMatch(part.substring(1))) continue;
      if (_capital.hasMatch(part[0]) && !sentenceStart(text, start)) continue;
      words.add((start: start, end: start + part.length, word: part));
    }
  }
  return words;
}

/// Whether what's at [at] in [text] starts a sentence: the text's start, or
/// after `.`, `!`, `?`, `:` or a new line, with spaces between at most.
bool sentenceStart(String text, int at) {
  var i = at;
  while (i > 0 && (text[i - 1] == ' ' || text[i - 1] == '\t')) {
    i--;
  }
  return i == 0 || '.!?:\n'.contains(text[i - 1]);
}

/// [word] as sets of known words hold it: its case and curly apostrophes
/// don't matter.
String knownForm(String word) => word.toLowerCase().replaceAll('’', "'");

/// The words of [messages], each in its [knownForm].
Set<String> wordsOf(Iterable<String> messages) => {
  for (final text in messages)
    for (final m in _agentWord.allMatches(text)) knownForm(m[0]!),
};

/// [fix] in [word]'s shape: capitalized if the word was. All capitals never
/// come here, as [scanWords] skips them.
String inShapeOf(String word, String fix) =>
    fix.isEmpty || !_capital.hasMatch(word[0])
    ? fix
    : fix[0].toUpperCase() + fix.substring(1);
