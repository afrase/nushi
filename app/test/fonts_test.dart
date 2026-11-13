// Font family names (ADR 0114): what can be one, whoever wrote it, and
// what a font menu lists of the system's answer; the Mac's channel.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/fonts.dart';
import 'package:nushi/fonts_macos.dart';

void main() {
  test('a family name is one line of printable text, a hundred characters '
      'at most', () {
    for (final name in [
      'Menlo',
      'SF Mono',
      '.AppleSystemUIFont',
      'Fira Code, Retina',
      'Noto Sans CJK 日本語',
      'Źródło Sans 3',
      'x' * 100,
    ]) {
      expect(isFamilyName(name), isTrue, reason: name);
    }
    for (final (name, why) in [
      ('', 'empty'),
      ('x' * 101, 'too long'),
      (' Menlo', 'a space first'),
      ('Menlo ', 'a space last'),
      ('Men\nlo', 'a line break'),
      ('Men\tlo', 'a tab'),
      ('Menlo\u0000', 'a NUL'),
      ('Men\u001b[31mlo', 'an escape'),
      ('Men\u007flo', 'DEL'),
      ('Men\u0085lo', 'a C1 control'),
      ('Men\u2028lo', 'a line separator'),
      ('Men\u2029lo', 'a paragraph separator'),
      ('ol\u202eneM', 'a direction override'),
      ('Men\u200blo', 'a zero-width space'),
      ('Men\ue000lo', 'a private-use character'),
    ]) {
      expect(isFamilyName(name), isFalse, reason: why);
    }
  });

  test('a menu lists the names that can be names, each once, in order '
      'whatever their case, without private families and the bundled '
      'one', () {
    expect(
      listedFamilies([
        'Zapfino',
        'menlo',
        'Andale Mono',
        '.SF NS Mono',
        'IBM Plex Sans',
        'Menlo',
        'Andale Mono',
        'avenir',
        '',
        'Bad\nName',
        'x' * 300,
        'Avenir Next',
      ], but: 'IBM Plex Sans'),
      ['Andale Mono', 'avenir', 'Avenir Next', 'Menlo', 'menlo', 'Zapfino'],
    );
    expect(listedFamilies(null), isEmpty);
    expect(listedFamilies(const []), isEmpty);
  });

  testWidgets('the Mac asks its channel for every family and for the '
      'monospaced ones, and names the system font', (tester) async {
    final asked = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('nushi/fonts'),
      (call) async {
        asked.add(call.method);
        return call.method == 'families'
            ? <String>['Avenir', 'Menlo']
            : <String>['Menlo'];
      },
    );
    const fonts = MacFonts();
    expect(await fonts.families(), ['Avenir', 'Menlo']);
    expect(await fonts.monospaced(), ['Menlo']);
    expect(asked, ['families', 'monospaced']);
    expect(fonts.system, '.AppleSystemUIFont');
    expect(isFamilyName(fonts.system), isTrue);
  });
}
