import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('nushi/spelling');

/// What judges words for spell check (ADR 0083). A failing call is for its
/// caller to swallow: spell check never gets in the way of typing.
abstract interface class Speller {
  /// Which of [words] are misspelled.
  Future<List<String>> misspelled(List<String> words);

  /// Better spellings of [word], the likeliest first.
  Future<List<String>> guesses(String word);

  /// Stops flagging [word] until the app quits.
  Future<void> ignore(String word);

  /// Stops flagging [word] for good, by adding it to the user's dictionary.
  Future<void> learn(String word);
}

/// The Mac's own spell checker, from `macos/Runner/Spelling.swift`.
class MacSpeller implements Speller {
  const new();

  @override
  Future<List<String>> misspelled(List<String> words) async =>
      await _channel.invokeListMethod<String>('check', words) ?? const [];

  @override
  Future<List<String>> guesses(String word) async =>
      await _channel.invokeListMethod<String>('guesses', word) ?? const [];

  @override
  Future<void> ignore(String word) => _channel.invokeMethod('ignore', word);

  @override
  Future<void> learn(String word) => _channel.invokeMethod('learn', word);
}

/// A test's stand-in: a test must never reach the real checker, whose
/// [Speller.learn] writes the user's own dictionary.
@visibleForTesting
Speller? testSpeller;

/// The speller, on the Mac only: a phone's browser has its own spell check.
Speller? get speller =>
    testSpeller ??
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS
        ? const MacSpeller()
        : null);
