import 'package:flutter/foundation.dart';

import 'package:nushi/native.dart';

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

/// The speller: the platform's ([Native.speller]), on the Mac, and on
/// Linux where enchant has a dictionary for the user's language; not on
/// the phone, whose browser has its own spell check. A test sets its own:
/// it must never reach the real checker, whose [Speller.learn] writes the
/// user's own dictionary.
Speller? get speller => kIsWeb ? null : native.speller;
