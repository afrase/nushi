import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets('a menu asked to opens over its opener, just clear of it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: Center(
            child: Menu(
              above: true,
              entries: [
                MenuEntry('Mention a file', onPick: () {}),
                MenuEntry('Image…', onPick: () {}),
              ],
              builder: (context, open) =>
                  TextButton(onPressed: open, child: const Text('Open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    final last = tester.getRect(find.byType(MenuItemButton).last);
    final opener = tester.getRect(
      find.ancestor(of: find.text('Open'), matching: find.byType(TextButton)),
    );
    // Its last row, then the panel's padding and border, then the gap.
    expect(last.bottom, moreOrLessEquals(opener.top - 4 - 6, epsilon: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
