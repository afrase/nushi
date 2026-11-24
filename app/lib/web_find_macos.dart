import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/web_find.dart';

// A WKWebView's find (issue 63, ADR 0143): the Swift side's `PageFind`
// (`macos/Runner/PageFind.swift`) runs its script (`PageFind.js`) in a
// content world of its own, so the page's scripts neither see its
// variables nor change what it calls; it marks the matches with the CSS
// Custom Highlight API, which changes nothing in the page's text.

const _browser = MethodChannel('nushi/browser');

/// A colour as CSS has it.
String _css(Color c) =>
    'rgba(${(c.r * 255).round()}, ${(c.g * 255).round()}, '
    '${(c.b * 255).round()}, ${c.a.toStringAsFixed(3)})';

/// The find of the plugin's web view numbered [id] (`webViewIdentifier`).
class WebKitFinder implements PageFinder {
  new(this.id);

  /// The web view's number, once it's made.
  final int Function() id;

  /// Counts the pages that finished loading.
  final _loaded = ValueNotifier<int>(0);

  /// Its page finished loading: what was marked is gone.
  void pageLoaded() => _loaded.value++;

  @override
  Listenable get loaded => _loaded;

  Future<PageFound> _run(Map<String, Object> args) async {
    final r = await _browser.invokeMapMethod<String, Object?>('find', {
      'id': id(),
      ...args,
    });
    return (
      count: (r?['count'] as num?)?.toInt() ?? 0,
      at: (r?['at'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<PageFound> find(
    String query, {
    required int at,
    required FindColors colors,
    required double cover,
  }) => _run({
    'op': 'find',
    'query': query,
    'at': at,
    'hit': _css(colors.hit),
    'now': _css(colors.now),
    'edge': _css(colors.edge),
    'cover': cover,
  });

  @override
  Future<PageFound> show(int at, {required double cover}) =>
      _run({'op': 'show', 'at': at, 'cover': cover});

  @override
  Future<void> clear() => _run({'op': 'clear'});

  @override
  Future<bool> focused() async =>
      await _browser.invokeMethod<bool>('pageFocused', id()) ?? false;

  @override
  Future<void> focus() => _browser.invokeMethod<void>('focusPage', id());
}
