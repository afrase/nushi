// Every press control is a button to a screen reader, as its look says,
// but a Toggle, which is a switch, and a LinkText, which is a link: walked
// over the component gallery (test/gallery), which builds every control.
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'gallery/sheets.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);

  for (final sheet in sheets) {
    testWidgets("the gallery's ${sheet.name}: each press control says "
        'what it is', (tester) async {
      final semantics = tester.ensureSemantics();
      await drawSheet(tester, sheet, Tokens.dark);
      var checked = 0;
      for (final e in find.byType(Pressable).evaluate().toList()) {
        if ((e.widget as Pressable).onTap == null) continue;
        final node = tester.getSemantics(
          find
              .descendant(
                of: find.byElementPredicate((x) => x == e),
                matching: find.byType(PressWatch),
              )
              .first,
        );
        bool inside(Type t) => find
            .ancestor(
              of: find.byElementPredicate((x) => x == e),
              matching: find.byType(t),
            )
            .evaluate()
            .isNotEmpty;
        final what = '${e.widget} in ${sheet.name}';
        if (inside(Toggle)) {
          expect(
            node,
            isSemantics(
              hasToggledState: true,
              isButton: false,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
              hasFocusAction: true,
              isFocusable: true,
              isToggled: node.flagsCollection.isToggled.toBoolOrNull(),
            ),
            reason: '$what: a switch',
          );
        } else if (inside(LinkText)) {
          expect(node.flagsCollection.isLink, isTrue, reason: '$what: a link');
          expect(node.flagsCollection.isButton, isFalse, reason: what);
        } else {
          expect(node.flagsCollection.isButton, isTrue, reason: what);
          expect(
            node.flagsCollection.isEnabled.toBoolOrNull(),
            isTrue,
            reason: what,
          );
        }
        checked++;
      }
      for (final e in find.byType(Tap).evaluate()) {
        if ((e.widget as Tap).onTap == null) continue;
        final node = tester.getSemantics(
          find
              .descendant(
                of: find.byElementPredicate((x) => x == e),
                matching: find.byType(PressWatch),
              )
              .first,
        );
        expect(node.flagsCollection.isButton, isTrue, reason: '${e.widget}');
        checked++;
      }
      if (sheet.name == 'buttons') expect(checked, greaterThan(20));
      semantics.dispose();
    }, variant: onMac);
  }
}
