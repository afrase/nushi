import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const _model = 'claude-opus-5-5[1m]';

void main() {
  setUpAll(loadFonts);

  // UX review, finding 6: at 720 wide (the sidebar 260) the header's
  // terminal, details and ⋯ were clipped.
  for (final width in [720.0, 1700.0]) {
    testWidgets('the whole window, $width wide: ⋯ at the header’s end', (
      tester,
    ) async {
      viewport(tester, Size(width, 600), brightness: Brightness.dark);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('nushi/fonts'),
            (_) async => <String>[],
          );
      paneWidths.value = {};
      showDetails.value = true;
      final link = GitHubLink(
        host: 'github.com',
        repo: 'afrase/nushi',
        number: 12,
        pull: true,
      );
      final fake =
          FakeDaemon([
              chat('c', 'claude', 'Fix the login redirect after it expires')
                ..pull = link,
            ])
            ..answer = (input) => switch (input) {
              FindChatPullRequest() => FindChatPullResponse(
                host: 'github.com',
                repo: 'afrase/nushi',
                branch: 'login',
                pull: link,
              ),
              GetChatRequest() => GetChatResponse(
                config: [
                  ConfigOption(
                    id: 'model',
                    category: 'model',
                    current: _model,
                    values: [ConfigValue(value: _model, name: _model)],
                  ),
                ],
              ),
              _ => null,
            };
      final d = await fake.connect(tester);
      d.select('c');
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final header = tester.getRect(find.byType(ChatHeader));
      final menu = tester.getRect(find.byTooltip('Chat menu'));
      expect(menu.right, closeTo(header.right - 8, 1));
      expect(header.right, width);
      await expectLater(
        find.byType(NushiApp),
        matchesGoldenFile('goldens/header_window_${width.toInt()}_dark.png'),
      );
      d.dispose();
    }, variant: _mac);
  }
}
