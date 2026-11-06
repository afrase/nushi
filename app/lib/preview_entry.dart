import 'package:flutter/foundation.dart';

import 'package:nushi/tool_parts.dart' show plainPath;

/// What a preview tab shows (ADR 0070, 0094): a file the chat names, or a
/// browser tab's page.
sealed class PreviewEntry {
  const new();
}

/// A file's tab, by the name it was opened with (relative to the chat's
/// folder, or absolute): two of one name are one tab.
@immutable
final class PreviewFile extends PreviewEntry {
  const new(this.path);

  final String path;

  @override
  bool operator ==(Object other) => other is PreviewFile && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'PreviewFile($path)';
}

/// A browser tab (ADR 0094): a page of a web server on this Mac. It's the
/// same tab however it navigates, so it's told apart by identity; its view
/// sets its address and title as the page moves.
final class BrowserTab extends PreviewEntry {
  new([String address = '']) : address = ValueNotifier(address);

  /// The page's address, '' for a new tab (its address field and a hint).
  final ValueNotifier<String> address;

  /// The page's own title, '' until it has one.
  final title = ValueNotifier<String>('');

  /// The view showing it, while one does: ⌘L and ⌘R reach it there.
  BrowserControls? view;

  /// What its tab says: the page's title, else its address without the
  /// scheme, else "New tab". A page names itself, so its bidi and control
  /// marks show (plainPath), and a title is cut at [_titleMost].
  String get label {
    final t = title.value.trim();
    if (t.isNotEmpty) {
      return plainPath(t.length > _titleMost ? t.substring(0, _titleMost) : t);
    }
    final a = address.value;
    if (a.isEmpty) return 'New tab';
    return plainPath(a.replaceFirst(RegExp('^https?://'), ''));
  }

  static const _titleMost = 120;

  @override
  String toString() => 'BrowserTab(${address.value})';
}

/// What the app's keys ask of the browser tab showing: ⌘L and ⌘R.
abstract interface class BrowserControls {
  /// Puts the focus in the address field, its text selected.
  void focusAddress();

  /// Loads the page again.
  void reload();
}
