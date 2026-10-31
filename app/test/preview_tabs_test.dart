import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/artifacts_widget.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/web_page.dart';
import 'package:xterm2/xterm.dart' hide Terminal;

import 'fake_daemon.dart';
import 'harness.dart';

const _three = ['docs/report.md', 'docs/plan.md', 'site/notes.md'];

/// A dozen files, some with long names: more than any pane's row holds.
const _many = [
  'docs/release-report-week-of-october-26.md',
  'docs/plan.md',
  'site/notes.md',
  'docs/architecture-of-the-preview-pane.md',
  'docs/one.md',
  'docs/two.md',
  'docs/three.md',
  'docs/four.md',
  'docs/five-is-a-rather-longer-name-than-four.md',
  'docs/six.md',
  'docs/seven.md',
  'docs/eight.md',
];

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Item _wrote(String id, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'edit',
  title: 'Write',
  status: 'completed',
  paths: [path],
);

final _items = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Write the report and the plan.',
  ),
  _wrote('r', 'docs/report.md'),
  Item(id: 'm1', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Wrote it.'),
  _wrote('p', 'docs/plan.md'),
  Item(id: 'm2', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Both done.'),
];

/// A page host that counts the ones alive and the ones made.
class _Page implements PageHost {
  new(this.live, this.made) {
    live.value++;
    made.value++;
  }

  final ValueNotifier<int> live;
  final ValueNotifier<int> made;

  @override
  Widget view(BuildContext context) =>
      const ColoredBox(color: Color(0xFFFBF7F0), child: SizedBox.expand());

  @override
  Future<void> load(String path, String root) async {}

  @override
  Future<void> reload() async {}

  @override
  void dispose() => live.value--;
}

/// The daemon: every file answered with a text of its own, its stream left
/// open.
FakeDaemon _fake() {
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final c = chat('c', 'claude', 'Write the release report');
  return FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: c, items: _items),
      ListTerminalsRequest(:final chatId) => ListTerminalsResponse(
        terminals: [
          Terminal(id: 't1', chatId: chatId, folder: '/tmp', shell: 'zsh'),
        ],
      ),
      _ => null,
    })
    ..streams = (input) {
      if (input is AttachTerminalRequest) {
        return StreamController<AttachTerminalResponse>().stream;
      }
      if (input is! WatchChatFileRequest) return null;
      final text = '# Title of ${baseName(input.path)}\n\nAll well here.\n';
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        WatchChatFileResponse(
          path: '/Users/me/nushi/${input.path}',
          data: utf8.encode(text),
          size: Int64(text.length),
        ),
      );
      return s.stream;
    };
}

/// The app on the chat, [files] open in the preview (the first showing
/// unless [last]).
Future<Daemon> _app(
  WidgetTester tester, {
  double width = 1700,
  Brightness? brightness,
  List<String> files = const [],
  bool last = false,
  bool details = false,
}) async {
  viewport(tester, Size(width, 900), brightness: brightness);
  showDetails.value = details;
  paneWidths.value = {};
  final d = await _fake().connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  final c = d.chats['c']!;
  files.forEach(c.openPreview);
  if (files.isNotEmpty && !last) c.openPreview(files.first);
  await tester.pumpAndSettle();
  return d;
}

Finder _inPane(Finder f) =>
    find.descendant(of: find.byType(PreviewPane), matching: f);

Finder _tab(String label) => find.ancestor(
  of: find.descendant(of: find.byType(PreviewTabs), matching: find.text(label)),
  matching: find.byWidgetPredicate(
    (w) => w is SizedBox && w.key is ValueKey<String>,
  ),
);

Finder _closeOf(String label) =>
    find.descendant(of: _tab(label), matching: find.byTooltip('Close tab'));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool meta = false,
}) async {
  if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

ScrollPosition _row(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(PreviewTabs),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

/// Where everything around the name is: none of it may move between one
/// file and three.
Map<String, Rect> _marks(WidgetTester tester) {
  Rect at(Finder f) => tester.getRect(f);
  return {
    'pane': at(find.byType(PreviewPane)),
    'title row': at(_inPane(find.byType(PaneHeader))),
    'kind icon': at(_inPane(find.byType(Icon)).first),
    'Preview': at(_inPane(find.text('Preview'))),
    'Source': at(_inPane(find.text('Source'))),
    'Live': at(_inPane(find.byType(LiveMark))),
    'Show in Finder': at(_inPane(find.byTooltip('Show in Finder'))),
    'Close': at(_inPane(find.byTooltip('Close'))),
    'body': at(_inPane(find.byType(PreviewBody))),
    'transcript': at(find.byType(Transcript)),
    'chat header': at(find.byType(ChatHeader)),
    'header’s tabs': at(find.byType(PlainTabs<ChatTab>)),
    'chat menu': at(find.byTooltip('Chat menu')),
    'Chat': at(
      find.descendant(of: find.byType(ChatHeader), matching: find.text('Chat')),
    ),
    'Changes': at(
      find.descendant(
        of: find.byType(ChatHeader),
        matching: find.text('Changes'),
      ),
    ),
  };
}

void main() {
  setUpAll(loadFonts);

  group('the open files', () {
    ChatState state() => ChatState('c', '/Users/me/nushi');

    test('a file opens once, however it’s named', () {
      final c = state()
        ..openPreview('docs/a.md')
        ..openPreview('docs/b.md')
        ..openPreview('/Users/me/nushi/docs/a.md');
      expect(c.previewFiles.value, ['docs/a.md', 'docs/b.md']);
      expect(c.preview.value, 'docs/a.md');
      c.openPreview('./docs/b.md');
      expect(c.previewFiles.value, ['docs/a.md', 'docs/b.md']);
      expect(c.preview.value, 'docs/b.md');
    });

    test('closing the one showing shows the one after it, or the last', () {
      final c = state()
        ..openPreview('a.md')
        ..openPreview('b.md')
        ..openPreview('c.md')
        ..openPreview('b.md')
        ..closePreviewFile('b.md');
      expect(c.preview.value, 'c.md');
      c.closePreviewFile('c.md');
      expect(c.preview.value, 'a.md');
      c.closePreviewFile('a.md');
      expect(c.preview.value, isNull);
      expect(c.previewFiles.value, isEmpty);
    });

    test('closing another leaves the one showing', () {
      final c = state()
        ..openPreview('a.md')
        ..openPreview('b.md')
        ..closePreviewFile('a.md');
      expect(c.preview.value, 'b.md');
      expect(c.previewFiles.value, ['b.md']);
      c.closePreviewFile('nothing.md');
      expect(c.previewFiles.value, ['b.md']);
    });

    test('a subagent’s pane closes the preview, tabs and all', () {
      final c = state()
        ..openPreview('a.md')
        ..openPreview('b.md');
      c.pane.value = 'agent';
      expect(c.preview.value, isNull);
      expect(c.previewFiles.value, isEmpty);
      c.openPreview('c.md');
      expect(c.pane.value, isNull);
      expect(c.previewFiles.value, ['c.md']);
    });
  });

  group('tabs’ widths', () {
    test('that fit stay as they are', () {
      expect(fitTabs([100, 200], 300), [100, 200]);
    });

    test('the widest give way first, the row just filled', () {
      final fitted = fitTabs([100, 300, 500], 700);
      expect(fitted[0], 100);
      expect(fitted[1], closeTo(300, 0.01));
      expect(fitted[2], closeTo(300, 0.01));
      expect(fitted.reduce((a, b) => a + b), closeTo(700, 0.01));
    });

    test('none below the least; then they scroll', () {
      final fitted = fitTabs([200, 200, 200], 150);
      expect(fitted, everyElement(previewTabLeast));
      // One already narrower stays so.
      expect(fitTabs([50, 200, 200], 100), [50, 88, 88]);
    });
  });

  test('a label says the folder only when two share a name', () {
    const files = ['docs/plan.md', 'site/plan.md', 'a.md'];
    expect(tabLabel('docs/plan.md', files), 'plan.md · docs');
    expect(tabLabel('a.md', files), 'a.md');
  });

  group('the pane', () {
    testWidgets('one file: its name and menu, no tabs', (tester) async {
      final d = await _app(tester, files: _three.take(1).toList());
      expect(find.byType(PreviewTabs), findsNothing);
      expect(_inPane(find.byType(FilesMenu)), findsOneWidget);
      expect(_inPane(find.text('report.md')), findsOneWidget);
      d.dispose();
    }, variant: _mac);

    for (final width in [1700.0, 720.0]) {
      testWidgets('nothing moves from one file to three, ${width.toInt()} '
          'wide', (tester) async {
        final d = await _app(
          tester,
          width: width,
          files: _three.take(1).toList(),
        );
        final c = d.chats['c']!;
        // The live mark is lit by each file's first answer, in both.
        final one = _marks(tester);
        final name = tester.getRect(_inPane(find.text('report.md')));
        _three.forEach(c.openPreview);
        c.openPreview(_three.first);
        await tester.pumpAndSettle();
        expect(find.byType(PreviewTabs), findsOneWidget);
        expect(_marks(tester), one);
        // The name it had is the first tab's, to the pixel.
        final first = tester.getRect(_inPane(find.text('report.md')));
        expect(first.left, name.left);
        expect(first.center.dy, name.center.dy);
        d.dispose();
      }, variant: _mac);
    }

    // The pane lies under the chat header, not beside it: the two rows share
    // a height and an edge, and each row's lines stop on its own border.
    for (final count in [1, 3]) {
      testWidgets('the title row is the header’s height, right under it, '
          '$count open', (tester) async {
        final d = await _app(tester, files: _three.take(count).toList());
        final header = tester.getRect(find.byType(ChatHeader));
        final row = tester.getRect(_inPane(find.byType(PaneHeader)));
        expect(header.height, 44);
        expect(row.height, 44);
        expect(row.top, header.bottom);
        expect(row.bottom, header.bottom + 44);
        final lines = find.descendant(
          of: find.byType(TabFace),
          matching: find.byType(Positioned),
        );
        // Chat, Preview and, with three open, the file showing.
        expect(lines, findsNWidgets(count == 1 ? 2 : 3));
        for (final line in lines.evaluate()) {
          final box = line.renderObject! as RenderBox;
          final bottom = box.localToGlobal(box.size.bottomLeft(Offset.zero)).dy;
          expect(bottom, anyOf(header.bottom - 1, row.bottom - 1));
        }
        d.dispose();
      }, variant: _mac);
    }

    testWidgets('no file in the chat header', (tester) async {
      final d = await _app(tester, files: _three);
      for (final name in ['report.md', 'plan.md', 'notes.md']) {
        expect(
          find.descendant(
            of: find.byType(ChatHeader),
            matching: find.text(name),
          ),
          findsNothing,
        );
      }
      expect(readSaved().keys, isNot(contains('previewTabs')));
      d.dispose();
    }, variant: _mac);

    testWidgets('a tab shows its file, and its ✕ closes it', (tester) async {
      final d = await _app(tester, files: _three);
      final c = d.chats['c']!;
      await _tap(tester, _inPane(find.text('plan.md')));
      expect(c.preview.value, 'docs/plan.md');
      expect(
        _inPane(find.text('Title of plan.md', findRichText: true)),
        findsOneWidget,
      );
      await _tap(tester, _closeOf('plan.md'));
      expect(c.previewFiles.value, ['docs/report.md', 'site/notes.md']);
      expect(c.preview.value, 'site/notes.md');
      await _tap(tester, _closeOf('notes.md'));
      expect(find.byType(PreviewTabs), findsNothing, reason: 'one left');
      expect(_inPane(find.byType(FilesMenu)), findsOneWidget);
      d.dispose();
    }, variant: _mac);

    testWidgets('the ✕ shows on the tab showing and under the pointer', (
      tester,
    ) async {
      final d = await _app(tester, files: _three);
      double close(String label) => tester
          .widget<Opacity>(
            find.descendant(of: _tab(label), matching: find.byType(Opacity)),
          )
          .opacity;
      expect(close('report.md'), 1);
      expect(close('plan.md'), 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(_tab('plan.md')));
      await tester.pump();
      expect(close('plan.md'), 1);
      expect(close('notes.md'), 0);
      d.dispose();
    }, variant: _mac);

    testWidgets('the pane’s Close closes it and forgets the tabs', (
      tester,
    ) async {
      final d = await _app(tester, files: _three);
      final c = d.chats['c']!;
      await _tap(tester, _inPane(find.byTooltip('Close')));
      expect(find.byType(PreviewPane), findsNothing);
      expect(c.previewFiles.value, isEmpty);
      c.openPreview('site/notes.md');
      await tester.pumpAndSettle();
      expect(find.byType(PreviewTabs), findsNothing);
      d.dispose();
    }, variant: _mac);

    testWidgets('its width is one, across tabs', (tester) async {
      final d = await _app(tester, files: _three);
      paneWidths.value = {'preview': 700};
      await tester.pumpAndSettle();
      double width() => tester.getSize(find.byType(PreviewPane)).width;
      expect(width(), 700);
      await _tap(tester, _inPane(find.text('notes.md')));
      expect(width(), 700);
      await _tap(tester, _closeOf('notes.md'));
      expect(width(), 700);
      d.dispose();
    }, variant: _mac);

    testWidgets('Source is remembered per file', (tester) async {
      final d = await _app(tester, files: _three);
      Finder source(String name) =>
          _inPane(find.textContaining('# Title of $name', findRichText: true));
      await _tap(tester, _inPane(find.text('plan.md')));
      await _tap(tester, _inPane(find.text('Source')));
      expect(source('plan.md'), findsOneWidget);
      await _tap(tester, _inPane(find.text('report.md')));
      expect(source('report.md'), findsNothing);
      await _tap(tester, _inPane(find.text('plan.md')));
      expect(source('plan.md'), findsOneWidget);
      expect(
        tester.widget<SourceSwitch>(_inPane(find.byType(SourceSwitch))).source,
        isTrue,
      );
      d.dispose();
    }, variant: _mac);

    testWidgets('a file’s view is made again as it shows, one at a time', (
      tester,
    ) async {
      final live = ValueNotifier(0);
      final made = ValueNotifier(0);
      final was = newPageHost;
      newPageHost = () => _Page(live, made);
      addTearDown(() => newPageHost = was);
      final d = await _app(
        tester,
        files: const ['site/a.html', 'site/b.html'],
        last: true,
      );
      expect(live.value, 1);
      final before = made.value;
      await _tap(tester, _inPane(find.text('a.html')));
      await _tap(tester, _inPane(find.text('b.html')));
      expect(live.value, 1);
      expect(made.value, before + 2);
      await closeView(tester, d);
    }, variant: _mac);
  });

  group('every way in', () {
    testWidgets('a tool row’s Preview, and the same file again', (
      tester,
    ) async {
      final d = await _app(tester);
      final c = d.chats['c']!;
      Finder preview(String id) => find.descendant(
        of: find.byWidgetPredicate((w) => w is ToolCallView && w.item.id == id),
        matching: find.byType(PreviewButton),
      );
      await _tap(tester, preview('r'));
      expect(c.previewFiles.value, ['docs/report.md']);
      await _tap(tester, preview('p'));
      expect(c.previewFiles.value, ['docs/report.md', 'docs/plan.md']);
      expect(find.byType(PreviewTabs), findsOneWidget);
      await _tap(tester, preview('r'));
      expect(c.previewFiles.value, hasLength(2));
      expect(c.preview.value, 'docs/report.md');
      d.dispose();
    }, variant: _mac);

    testWidgets('the Files list, and the name’s menu', (tester) async {
      final d = await _app(tester, details: true);
      final c = d.chats['c']!;
      await _tap(
        tester,
        find.descendant(
          of: find.byType(FileRows),
          matching: find.text('plan.md'),
        ),
      );
      expect(c.previewFiles.value, ['docs/plan.md']);
      await _tap(tester, _inPane(find.byType(FilesMenu)));
      await _tap(tester, find.text('report.md').last);
      expect(c.previewFiles.value, ['docs/plan.md', 'docs/report.md']);
      expect(c.preview.value, 'docs/report.md');
      d.dispose();
    }, variant: _mac);
  });

  group('⌘W', () {
    testWidgets('closes the tab showing, and with the last the pane', (
      tester,
    ) async {
      final d = await _app(tester, files: _three.take(2).toList());
      final c = d.chats['c']!;
      await _key(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(c.previewFiles.value, ['docs/plan.md']);
      await _key(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(find.byType(PreviewPane), findsNothing);
      await _key(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(c.preview.value, isNull);
      d.dispose();
    }, variant: _mac);

    testWidgets('leaves a preview out of sight', (tester) async {
      final d = await _app(tester, files: _three.take(2).toList());
      final c = d.chats['c']!..tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(c.previewFiles.value, hasLength(2));
      d.dispose();
    }, variant: _mac);

    testWidgets('a focused terminal keeps it', (tester) async {
      terminalChats.value = {'c'};
      final d = await _app(tester, files: _three.take(2).toList());
      await _tap(tester, find.byType(TerminalView));
      await _key(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(d.chats['c']!.previewFiles.value, hasLength(2));
      d.dispose();
    }, variant: _mac);

    testWidgets('leaves the tab under a dialog; the menu bar’s too', (
      tester,
    ) async {
      final d = await _app(tester, files: _three.take(2).toList());
      final c = d.chats['c']!;
      await _key(tester, LogicalKeyboardKey.keyK, meta: true);
      expect(find.byType(Palette), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(c.previewFiles.value, hasLength(2));
      // File › Close Tab, where a ⌘W no widget takes goes (a web page's).
      final navigator = tester.element(find.byType(Navigator).first);
      runAct(navigator, d, Act.closeTab);
      await tester.pumpAndSettle();
      expect(c.previewFiles.value, hasLength(2));
      await _key(tester, LogicalKeyboardKey.escape);
      runAct(navigator, d, Act.closeTab);
      await tester.pumpAndSettle();
      expect(c.previewFiles.value, ['docs/plan.md']);
      d.dispose();
    }, variant: _mac);
  });

  group('too many tabs', () {
    testWidgets('shrink to the least, scroll, and never overflow', (
      tester,
    ) async {
      final d = await _app(tester, files: _many, last: true);
      final row = _row(tester);
      expect(row.maxScrollExtent, greaterThan(0));
      // A long name stops at the least; a short one keeps its own width.
      double width(String label) => tester.getSize(_tab(label)).width;
      expect(width('one.md'), lessThan(previewTabLeast));
      expect(
        width('five-is-a-rather-longer-name-than-four.md'),
        previewTabLeast,
      );
      final rect = tester.getRect(find.byType(PreviewTabs));
      final shown = tester.getRect(_tab('eight.md'));
      expect(shown.right, lessThanOrEqualTo(rect.right + 0.5));
      expect(tester.takeException(), isNull);
      // The row doesn't run under the pane's controls.
      expect(
        rect.right,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Preview').last).dx),
      );
      d.dispose();
    }, variant: _mac);

    testWidgets('the pane at its narrowest: nothing overflows or overlaps', (
      tester,
    ) async {
      final d = await _app(tester, files: _three);
      paneWidths.value = {'preview': 300};
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PreviewPane)).width, 300);
      expect(_inPane(find.byTooltip('More')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(PreviewTabs));
      expect(row.width, greaterThan(0));
      expect(
        row.right,
        lessThanOrEqualTo(tester.getTopLeft(_inPane(find.text('Preview'))).dx),
      );
      d.dispose();
    }, variant: _mac);

    testWidgets('names that fit aren’t cut; those that don’t are', (
      tester,
    ) async {
      final d = await _app(tester, files: _many.take(3).toList());
      bool cut(String label) => tester
          .renderObject<RenderParagraph>(_inPane(find.text(label)))
          .didExceedMaxLines;
      expect(_row(tester).maxScrollExtent, lessThan(1), reason: 'they fit');
      expect(cut('release-report-week-of-october-26.md'), isTrue);
      expect(cut('plan.md'), isFalse);
      expect(cut('notes.md'), isFalse);
      d.dispose();
    }, variant: _mac);

    testWidgets('three short names fit the pane as it starts', (tester) async {
      final d = await _app(tester, files: _three);
      for (final name in ['report.md', 'plan.md', 'notes.md']) {
        expect(
          tester
              .renderObject<RenderParagraph>(_inPane(find.text(name)).first)
              .didExceedMaxLines,
          isFalse,
          reason: name,
        );
      }
      d.dispose();
    }, variant: _mac);

    testWidgets('picking a tab keeps the row where it is', (tester) async {
      final d = await _app(tester, files: _many, last: true);
      final before = tester.state(find.byType(PreviewTabs));
      final at = _row(tester).pixels;
      expect(at, greaterThan(0));
      await _tap(tester, _inPane(find.text('seven.md')));
      expect(d.chats['c']!.preview.value, 'docs/seven.md');
      expect(tester.state(find.byType(PreviewTabs)), same(before));
      expect(_row(tester).pixels, at);
      d.dispose();
    }, variant: _mac);

    testWidgets('a file opened brings its tab into view', (tester) async {
      final d = await _app(tester, files: _many, last: true);
      final c = d.chats['c']!..openPreview(_many.first);
      await tester.pumpAndSettle();
      expect(_row(tester).pixels, 0);
      c.openPreview(_many.last);
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(PreviewTabs));
      expect(
        tester.getRect(_tab('eight.md')).right,
        lessThanOrEqualTo(rect.right + 0.5),
      );
      d.dispose();
    }, variant: _mac);

    testWidgets('a wheel scrolls it sideways', (tester) async {
      final d = await _app(tester, files: _many, last: true);
      final row = _row(tester);
      final at = row.pixels;
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(PreviewTabs)),
          scrollDelta: const Offset(0, -120),
        ),
      );
      await tester.pumpAndSettle();
      expect(row.pixels, at - 120);
      d.dispose();
    }, variant: _mac);
  });

  group('goldens', () {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      for (final width in [1700.0, 720.0]) {
        for (final (count, files) in [
          ('one', _three.take(1).toList()),
          ('three', _three),
          ('many', _many),
        ]) {
          testWidgets('$count, $name, ${width.toInt()} wide', (tester) async {
            final d = await _app(
              tester,
              width: width,
              brightness: brightness,
              files: files,
              last: count == 'many',
            );
            final right = tester.getRect(find.byType(NushiApp)).right;
            expect(
              tester.getTopRight(find.byTooltip('Close')).dx,
              greaterThan(right - NushiTheme.gutter - 1),
            );
            await expectLater(
              find.byType(NushiApp),
              matchesGoldenFile(
                'goldens/preview_pane_${count}_${name}_${width.toInt()}.png',
              ),
            );
            d.dispose();
          }, variant: _mac);
        }
      }
    }
  });
}
