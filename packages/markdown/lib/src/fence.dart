/// CommonMark's code fences, the one reading of them both the renderer's
/// cut (blocks.dart) and heal use, so the two agree on where a code block
/// is.
library;

final _fence = RegExp('^ {0,3}(`{3,}|~{3,})');

/// The fence [line] opens a code block with (its run of backticks or
/// tildes), or null.
String? openingFence(String line) {
  final m = _fence.firstMatch(line);
  // A backtick fence's info string can't hold backticks.
  if (m == null || m[1]![0] == '`' && line.substring(m.end).contains('`')) {
    return null;
  }
  return m[1];
}

/// Whether [line] closes the block [fence] opened.
bool closesFence(String line, String fence) {
  final m = _fence.firstMatch(line);
  return m != null &&
      m[1]![0] == fence[0] &&
      m[1]!.length >= fence.length &&
      line.substring(m.end).trim().isEmpty;
}
