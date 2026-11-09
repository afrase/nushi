import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/speller_linux.dart';

void main() {
  test("the dictionary is the user's language, then the language alone; the "
      'C locale, or none, American English', () {
    expect(dictionaryTags({'LANG': 'en_GB.UTF-8'}), ['en_GB', 'en']);
    expect(
      dictionaryTags({
        'LANGUAGE': 'de_AT:de',
        'LC_ALL': 'fr_FR.UTF-8',
        'LANG': 'en_GB.UTF-8',
      }),
      ['de_AT', 'de'],
    );
    expect(
      dictionaryTags({'LANGUAGE': '', 'LC_MESSAGES': 'nl_NL', 'LANG': 'C'}),
      ['nl_NL', 'nl'],
    );
    expect(dictionaryTags({'LC_ALL': 'sr_RS.UTF-8@latin'}), ['sr_RS', 'sr']);
    expect(dictionaryTags({'LANG': 'eo'}), ['eo']);
    expect(dictionaryTags({'LANG': 'C.UTF-8'}), ['en_US']);
    expect(dictionaryTags({'LC_ALL': 'POSIX'}), ['en_US']);
    expect(dictionaryTags({}), ['en_US']);
  });

  test('without enchant there is no speller', () {
    expect(LinuxSpeller.open(library: 'libnothing-such.so.0'), isNull);
  });

  // Enchant itself, with an English dictionary (Arch's hunspell-en_us).
  // Its folder and personal list are in the test process's
  // XDG_CONFIG_HOME, inside its data folder (flutter_test_config.dart).
  final real = Platform.isLinux
      ? LinuxSpeller.open(environment: {'LANG': 'en_US.UTF-8'})
      : null;
  test('enchant flags, suggests, ignores for the session and learns into '
      'its personal list', () async {
    final speller = real!;
    expect(await speller.misspelled(['the', 'qick', '']), ['qick']);
    expect(await speller.guesses('qick'), contains('quick'));
    expect(await speller.guesses(''), isEmpty);
    // Words go to enchant as UTF-8 (one outside ASCII here: whether a
    // dictionary has a word like café differs, Ubuntu's hasn't).
    await speller.ignore('nushiword');
    await speller.ignore('nushïcafé');
    expect(await speller.misspelled(['nushiword', 'nushïcafé', 'qick']), [
      'qick',
    ]);
    await speller.learn('nushiflux');
    expect(await speller.misspelled(['nushiflux']), isEmpty);
    expect(
      File('$dataDir/config/enchant/en_US.dic').readAsLinesSync(),
      contains('nushiflux'),
    );
  }, skip: real == null ? 'needs enchant and an English dictionary' : false);
}
