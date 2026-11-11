import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const _model = 'claude-opus-5-5[1m]';

void main() {
  setUpAll(loadFonts);

  // UX review, finding 6: at 720 wide (the sidebar 260) the header's
  // terminal, details and ⋯ were clipped.
  final cases = [
    for (final width in [720.0, 1700.0])
      for (final (name, brightness) in [
        ('dark', Brightness.dark),
        ('light', Brightness.light),
      ])
        for (final preview in [false, true]) (width, name, brightness, preview),
  ];
  for (final (width, name, brightness, preview) in cases) {
    final pane = preview ? ', the preview open' : '';
    testWidgets('the whole window, $width wide, $name$pane: ⋯ at the '
        'header’s end', (tester) async {
      viewport(tester, Size(width, 600), brightness: brightness);
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
            ..answer = ((input) => switch (input) {
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
            })
            ..streams = (input) {
              if (input is! WatchChatFileRequest) return null;
              const text = '# The plan\n\nAll well here.\n';
              final s = StreamController<WatchChatFileResponse>();
              addTearDown(s.close);
              s.add(
                WatchChatFileResponse(
                  path: '/Users/me/nushi/${input.path}',
                  data: utf8.encode(text),
                  size: Int64(text.length),
                ),
              );
              return s.stream;
            };
      final d = await fake.connect(tester);
      d.select('c');
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      if (preview) {
        d.chats['c']!.openPreview('docs/plan.md');
        await tester.pumpAndSettle();
        expect(find.byType(PreviewPane), findsOneWidget);
        expect(find.byType(SourceButton), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      final header = tester.getRect(find.byType(ChatHeader));
      final menu = tester.getRect(find.byTooltip('Chat menu'));
      expect(menu.right, header.right - ChatHeader.end);
      // The header is the main pane's top, the window's margin in, the
      // details beside the pane where they show.
      final pane = tester.getRect(find.byType(Pane));
      expect(header.right, pane.right);
      expect(
        pane.right,
        width -
            NushiTheme.windowPad -
            (find.byType(DetailsPanel).evaluate().isEmpty
                ? 0
                : DetailsPanel.slot),
      );
      expect(header.top, NushiTheme.windowPad);
      expect(header.height, 56);
      // The segments in full, in the header's middle; at 720 this chat's
      // fold has made them a menu field.
      final tabs = find.descendant(
        of: find.byType(ChatHeader),
        matching: find.byType(Segmented<ChatTab>),
      );
      if (width > 720) {
        expect(tabs, findsOneWidget);
        expect(tester.getRect(tabs).top, greaterThan(header.top));
        expect(tester.getRect(tabs).bottom, lessThan(header.bottom - 1));
        expect(tester.getRect(tabs).right, lessThan(menu.left));
      } else {
        expect(tabs, findsNothing);
      }
      final file = preview ? 'header_window_preview' : 'header_window';
      await render(
        tester,
        find.byType(NushiApp),
        '${file}_${width.toInt()}_$name',
      );
      d.dispose();
    }, variant: _mac);
  }
}
