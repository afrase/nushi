import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/syntax.dart';

void main() {
  test("a code block's label names its language", () {
    expect(languageName('rb'), 'Ruby');
    expect(languageName('ruby'), 'Ruby');
    expect(languageName('go'), 'Go');
    expect(languageName('ts'), 'TypeScript');
    expect(languageName('not-a-language'), 'not-a-language');
  });
}
