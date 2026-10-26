import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

const _old = '''
class Ledger < Base
  # @return [Integer] the total, in cents
  def rolling_reserves_total_cents(days = 30)
    @total = rolling_reserve_amount_cents + self.fee(:usd)
  end
end
''';

const _new = '''
class Ledger < Base
  LIMIT = 5_000

  # @return [Integer] the total, in cents
  # @param days [Integer] how far back
  def rolling_reserves_total_cents(days = 30)
    @total = rolling_reserve_amount_cents + self.fee(:usd) + @@count
    puts "#{days} days: #{@total}", nil, LIMIT
  end
end
''';

const _block = r'''
A code block:

```ts
/** @param a the amount */
export class Ledger extends Base {
  total = 42;
  sum(a: number): string {
    return `${a} cents` + /x+/g;
  }
}
```
''';

/// A Ruby diff and a TypeScript code block, in both themes.
void main() {
  setUpAll(loadFonts);
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('syntax colors ($name)', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(900, 560);
      addTearDown(tester.view.reset);
      final theme = NushiTheme(tokens);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.toThemeData(),
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 240,
                  child: DiffBox(
                    FileChange(path: 'ledger.rb', oldText: _old, newText: _new),
                    fit: false,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: AgentMarkdown(_block),
                ),
              ],
            ),
          ),
        ),
      );
      // The diff's colors come from an isolate.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/syntax_$name.png'),
      );
    });
  }
}
