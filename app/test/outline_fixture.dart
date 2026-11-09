import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/markdown_outline.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/rail.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// What the Markdown outline's tests share (markdown_outline_test.dart, its
// looks in markdown_outline_look_test.dart): a roadmap to preview, the app
// on it, and the rail's parts.

const _go = 'somewhere to go when a heading is picked from the outline.';

/// A section's words: enough lines to scroll past.
String _words(String name) => [
  for (var i = 1; i <= 6; i++)
    'The $name section runs on for a while, line $i, so the view has $_go',
].join('\n\n');

/// A roadmap, as the screenshots' is: a title, sections and their parts.
final String roadmap = [
  '# Roadmap',
  _words('opening'),
  '## Plans',
  '### The app',
  _words('app'),
  '### Previews',
  _words('previews'),
  '### Changes and review',
  _words('changes'),
  '### GitHub',
  _words('GitHub'),
  '## Decisions to revisit',
  _words('decisions'),
].join('\n\n');

/// A note with one heading: no outline.
const flatNote = '# Notes\n\nNo other heading here, so no outline.\n';

/// The Mac.
final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The daemon: a chat whose folder holds `docs/roadmap.md` and
/// `docs/notes.md`; any other file is the notes' text.
FakeDaemon outlineDaemon() {
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final c = chat('c', 'claude', 'Plan the work', folder: '/Users/me/kettle');
  return FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: [
          Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Plan.'),
        ],
      ),
      _ => null,
    })
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      final text = input.path.endsWith('roadmap.md') ? roadmap : flatNote;
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        WatchChatFileResponse(
          path: input.path.startsWith('/')
              ? input.path
              : '/Users/me/kettle/${input.path}',
          data: utf8.encode(text),
          size: Int64(text.length),
        ),
      );
      return s.stream;
    };
}

/// The app on the chat, [file] in the preview.
Future<Daemon> outlineApp(
  WidgetTester tester, {
  double width = 1700,
  Brightness? brightness,
  String file = 'docs/roadmap.md',
}) async {
  viewport(tester, Size(width, 900), brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {};
  final d = await outlineDaemon().connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  d.chats['c']!.openPreview(file);
  await tester.pumpAndSettle();
  return d;
}

/// [f] in the preview pane.
Finder inPane(Finder f) =>
    find.descendant(of: find.byType(PreviewPane), matching: f);

/// The rail.
Finder get rail => find.byType(Rail);

/// The rail's current entry.
int railCurrent(WidgetTester tester) => tester.widget<Rail>(rail).current.value;

/// The outlined text's scroll.
ScrollPosition outlineScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(OutlinedMarkdown),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// The pointer, a mouse's, over the rail.
Future<TestGesture> hoverRail(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getTopLeft(rail) + const Offset(20, 14));
  await tester.pumpAndSettle();
  return mouse;
}
