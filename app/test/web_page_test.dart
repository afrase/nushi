import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/web_page.dart';

void main() {
  // Security review 2026-11-04, L5: a page the agent shows (no click,
  // ADR 0068) that leaves on its own (a script's location, a refresh)
  // opened the browser; only a press in the page just before does now.
  test('a page leaves for the browser only right after a press', () {
    const p = '/repo/out/page.html';
    final now = clock();
    const away = 'https://phish.example/login';
    expect(navigation(away, p, mainFrame: true), PageNavigation.drop);
    expect(
      navigation(
        away,
        p,
        mainFrame: true,
        pressed: now.subtract(const Duration(seconds: 5)),
      ),
      PageNavigation.drop,
    );
    expect(
      navigation(
        away,
        p,
        mainFrame: true,
        pressed: now.subtract(const Duration(milliseconds: 200)),
      ),
      PageNavigation.open,
    );
    expect(
      navigation('file://$p#menu', p, mainFrame: true),
      PageNavigation.stay,
    );
    expect(
      navigation(away, p, mainFrame: false),
      PageNavigation.stay,
    ); // a frame
  });
}
