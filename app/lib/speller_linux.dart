import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:nushi/speller.dart';

/// libc's malloc and free, for the strings enchant reads (the app has no
/// package:ffi).
@Native<Pointer<Uint8> Function(Size)>(symbol: 'malloc', isLeaf: true)
external Pointer<Uint8> _malloc(int size);

@Native<Void Function(Pointer<Void>)>(symbol: 'free', isLeaf: true)
external void _free(Pointer<Void> p);

typedef _Word = Void Function(Pointer<Void>, Pointer<Uint8>, IntPtr);
typedef _WordDart = void Function(Pointer<Void>, Pointer<Uint8>, int);

/// Linux's spell checker: enchant (libenchant-2, ADR 0102), the library
/// GNOME's and KDE's apps check with, over the user's own Hunspell, Nuspell
/// or Aspell dictionary in their language. Ignore lasts the session;
/// Learn adds the word to enchant's personal list
/// (`$XDG_CONFIG_HOME/enchant/<language>.dic`, a folder enchant makes when
/// a dictionary opens), which those apps share.
class LinuxSpeller implements Speller {
  new _(DynamicLibrary lib, this._dict)
    : _check = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Uint8>, IntPtr),
            int Function(Pointer<Void>, Pointer<Uint8>, int)
          >('enchant_dict_check'),
      _suggest = lib
          .lookupFunction<
            Pointer<Pointer<Uint8>> Function(
              Pointer<Void>,
              Pointer<Uint8>,
              IntPtr,
              Pointer<Size>,
            ),
            Pointer<Pointer<Uint8>> Function(
              Pointer<Void>,
              Pointer<Uint8>,
              int,
              Pointer<Size>,
            )
          >('enchant_dict_suggest'),
      _freeList = lib
          .lookupFunction<
            Void Function(Pointer<Void>, Pointer<Pointer<Uint8>>),
            void Function(Pointer<Void>, Pointer<Pointer<Uint8>>)
          >('enchant_dict_free_string_list'),
      _ignore = lib.lookupFunction<_Word, _WordDart>(
        'enchant_dict_add_to_session',
      ),
      _learn = lib.lookupFunction<_Word, _WordDart>('enchant_dict_add');

  /// Enchant's dictionary for the user's language ([dictionaryTags] of
  /// [environment]), or null without the library or such a dictionary:
  /// then there's no spell check, as a platform without one.
  static LinuxSpeller? open({
    Map<String, String>? environment,
    String library = 'libenchant-2.so.2',
  }) {
    final DynamicLibrary lib;
    try {
      lib = DynamicLibrary.open(library);
      // DynamicLibrary.open throws an ArgumentError for what it can't load.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      return null;
    }
    final broker = lib
        .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
          'enchant_broker_init',
        )();
    if (broker == nullptr) return null;
    final request = lib
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>),
          Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>)
        >('enchant_broker_request_dict');
    for (final tag in dictionaryTags(environment ?? Platform.environment)) {
      final dict = _withC(tag, (c, _) => request(broker, c));
      if (dict != nullptr) return LinuxSpeller._(lib, dict);
    }
    // The broker is kept for the app's life when there's a dictionary;
    // without one, there's nothing to free it for.
    return null;
  }

  final Pointer<Void> _dict;
  final int Function(Pointer<Void>, Pointer<Uint8>, int) _check;
  final Pointer<Pointer<Uint8>> Function(
    Pointer<Void>,
    Pointer<Uint8>,
    int,
    Pointer<Size>,
  )
  _suggest;
  final void Function(Pointer<Void>, Pointer<Pointer<Uint8>>) _freeList;
  final _WordDart _ignore;
  final _WordDart _learn;

  /// A word enchant can't judge (an error, below 0) isn't flagged.
  @override
  Future<List<String>> misspelled(List<String> words) async => [
    for (final w in words)
      if (w.isNotEmpty && _withC(w, (c, n) => _check(_dict, c, n)) > 0) w,
  ];

  @override
  Future<List<String>> guesses(String word) async {
    if (word.isEmpty) return const [];
    final count = _malloc(sizeOf<Size>()).cast<Size>();
    try {
      final list = _withC(word, (c, n) => _suggest(_dict, c, n, count));
      if (list == nullptr) return const [];
      try {
        return [for (var i = 0; i < count.value; i++) _fromC(list[i])];
      } finally {
        _freeList(_dict, list);
      }
    } finally {
      _free(count.cast());
    }
  }

  @override
  Future<void> ignore(String word) async {
    if (word.isNotEmpty) _withC(word, (c, n) => _ignore(_dict, c, n));
  }

  @override
  Future<void> learn(String word) async {
    if (word.isNotEmpty) _withC(word, (c, n) => _learn(_dict, c, n));
  }
}

/// Calls [f] with [s] as a C string of UTF-8 and its length in bytes,
/// freed after.
T _withC<T>(String s, T Function(Pointer<Uint8> c, int length) f) {
  final bytes = utf8.encode(s);
  final c = _malloc(bytes.length + 1);
  try {
    c.asTypedList(bytes.length + 1)
      ..setAll(0, bytes)
      ..[bytes.length] = 0;
    return f(c, bytes.length);
  } finally {
    _free(c.cast());
  }
}

/// The C string of UTF-8 at [p].
String _fromC(Pointer<Uint8> p) {
  var n = 0;
  while (p[n] != 0) {
    n++;
  }
  return utf8.decode(p.asTypedList(n), allowMalformed: true);
}

/// The dictionaries to ask enchant for, by the user's language: the first
/// of `LANGUAGE` (its first entry), `LC_ALL`, `LC_MESSAGES` and `LANG` set,
/// without its encoding or modifier (`en_GB.UTF-8` is `en_GB`), then its
/// language alone (`en`). The C locale, or none, is American English, the
/// app's own.
List<String> dictionaryTags(Map<String, String> environment) {
  final set = [
    (environment['LANGUAGE'] ?? '').split(':').first,
    environment['LC_ALL'],
    environment['LC_MESSAGES'],
    environment['LANG'],
  ].firstWhere((v) => v != null && v.isNotEmpty, orElse: () => '')!;
  final tag = set.split(RegExp('[.@]')).first;
  if (tag.isEmpty || tag == 'C' || tag == 'POSIX') return const ['en_US'];
  final language = tag.split('_').first;
  return [tag, if (language != tag) language];
}
