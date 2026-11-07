import 'package:flutter/services.dart';

import 'package:nushi/speller.dart';

const _channel = MethodChannel('nushi/spelling');

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
