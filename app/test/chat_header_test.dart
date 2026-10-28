import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

void main() {
  setUpAll(loadFonts);

  // A long title and a Codex model id fit a narrow window, cut short.
  for (final width in [560.0, 760.0, 1200.0]) {
    testWidgets('the header doesn’t overflow, $width wide', (tester) async {
      final d = await FakeDaemon([]).connect(tester);
      const model = 'accounts/fireworks/models/deepseek-v4p1-flash';
      final chat = ChatState('c', '/Users/me/repo')
        ..agent = 'codex'
        ..title = 'A title long enough to want all of the room it can get'
        ..config = [
          ConfigOption(
            id: 'model',
            category: 'model',
            current: model,
            values: [ConfigValue(value: model, name: model)],
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: const NushiTheme(Tokens.dark).toThemeData(),
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: ChatHeader(
                chat,
                d,
                tab: ChatTab.chat,
                onTab: (_) {},
                panel: true,
                onPanel: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(model), findsOneWidget);
      d.dispose();
    });
  }
}
