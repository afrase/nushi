import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/fonts_linux.dart';

void main() {
  test("Linux's monospaced fonts are fc-list's families, each by its first "
      'name, once, sorted', () async {
    final asked = <List<String>>[];
    final fonts = LinuxFonts(
      run: (program, arguments) async {
        asked.add([program, ...arguments]);
        return ProcessResult(
          1,
          0,
          'Liberation Mono\n'
              'DejaVu Sans Mono,DejaVu Sans Mono Book\n'
              'Adwaita Mono\n'
              'DejaVu Sans Mono\n'
              r'Fira Code\, Retina,Fira Code'
              '\n'
              '\n',
          '',
        );
      },
    );
    expect(await fonts.monospaced(), [
      'Adwaita Mono',
      'DejaVu Sans Mono',
      'Fira Code, Retina',
      'Liberation Mono',
    ]);
    expect(asked, [
      ['fc-list', ':spacing=mono', 'family'],
    ]);
  });

  test('no fc-list, or one that fails, is no answer', () async {
    final missing = LinuxFonts(
      run: (program, _) async =>
          throw ProcessException(program, const [], 'No such file', 2),
    );
    expect(await missing.monospaced(), isNull);
    final failing = LinuxFonts(
      run: (_, _) async => ProcessResult(1, 1, '', 'Fontconfig error'),
    );
    expect(await failing.monospaced(), isNull);
  });
}
