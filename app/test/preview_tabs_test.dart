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
import 'package:nushi/chat_header.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/files_top_row.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/pane_tabs.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/web_find.dart';
import 'package:nushi/web_page.dart';
import 'package:xterm2/xterm.dart' hide Terminal;

import 'browser_fixture.dart' show browserFakes;
import 'fake_daemon.dart';
import 'fake_web_views.dart';
import 'harness.dart';
import 'preview_fixture.dart';

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

final _items = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Write the report and the plan.',
  ),
  wrote('r', 'docs/report.md'),
  Item(id: 'm1', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Wrote it.'),
  wrote('p', 'docs/plan.md'),
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
  PageFinder? get finder => null;

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
  showDetails.value = details;
  paneWidths.value = {};
  final d = await openApp(
    tester,
    _fake(),
    size: Size(width, 900),
    brightness: brightness,
  );
  final c = d.chats['c']!;
  files.forEach(c.openInFiles);
  if (files.isNotEmpty && !last) c.openInFiles(files.first);
  await tester.pumpAndSettle();
  return d;
}

Finder _tab(String label) => find.ancestor(
  of: find.descendant(of: find.byType(PaneTabs), matching: find.text(label)),
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

ScrollPosition _row(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(PaneTabs),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

/// Where everything around the name is: none of it may move between one
/// file and three.
Map<String, Rect> _marks(WidgetTester tester) {
  Rect at(Finder f) => tester.getRect(f);
  // A pane at its least (a narrow window, ADR 0123) folds Show in Finder
  // into ⋯, and a header at the transcript's least folds the tabs.
  Rect? folds(Finder f) => f.evaluate().isEmpty ? null : at(f);
  return {
    'pane': at(find.byType(FilesPane)),
    'title row': at(inPane(find.byType(PaneHeader))),
    'kind icon': at(inPane(find.byType(Icon)).first),
    'path line': at(inPane(find.byType(PathLine))),
    'source button': at(inPane(find.byType(SourceButton))),
    'Live': at(inPane(find.byType(LiveMark))),
    'Show in Finder': ?folds(inPane(find.byTooltip('Show in Finder'))),
    'Close': at(inPane(find.byTooltip('Close'))),
    'body': at(inPane(find.byType(PreviewBody))),
    'transcript': at(find.byType(Transcript)),
    'chat header': at(find.byType(ChatHeader)),
    'header’s tabs': ?folds(find.byType(Segmented<ChatTab>)),
    'chat menu': at(find.byTooltip('Chat menu')),
    'Chat': ?folds(
      find.descendant(of: find.byType(ChatHeader), matching: find.text('Chat')),
    ),
    'Changes': ?folds(
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
        ..openInFiles('docs/a.md')
        ..openInFiles('docs/b.md')
        ..openInFiles('/Users/me/nushi/docs/a.md');
      expect(c.fileNames, ['docs/a.md', 'docs/b.md']);
      expect(c.shownFile, 'docs/a.md');
      c.openInFiles('./docs/b.md');
      expect(c.fileNames, ['docs/a.md', 'docs/b.md']);
      expect(c.shownFile, 'docs/b.md');
      c.openInFiles('/Users/me//nushi/./docs//a.md');
      expect(c.fileNames, ['docs/a.md', 'docs/b.md']);
      expect(c.shownFile, 'docs/a.md');
    });

    test('closing the one showing shows the one after it, or the last', () {
      final c = state()
        ..openInFiles('a.md')
        ..openInFiles('b.md')
        ..openInFiles('c.md')
        ..openInFiles('b.md')
        ..files.close(const PreviewFile('b.md'));
      expect(c.shownFile, 'c.md');
      c.files.close(const PreviewFile('c.md'));
      expect(c.shownFile, 'a.md');
      c.files.close(const PreviewFile('a.md'));
      expect(c.files.shown.value, isNull);
      expect(c.fileNames, isEmpty);
    });

    test('closing another leaves the one showing', () {
      final c = state()
        ..openInFiles('a.md')
        ..openInFiles('b.md')
        ..files.close(const PreviewFile('a.md'));
      expect(c.shownFile, 'b.md');
      expect(c.fileNames, ['b.md']);
      c.files.close(const PreviewFile('nothing.md'));
      expect(c.fileNames, ['b.md']);
    });

    test('a subagent’s pane opens beside the files, which keep their tabs', () {
      final c = state()
        ..openInFiles('a.md')
        ..openInFiles('b.md');
      c.pane.value = 'agent';
      expect(c.shownFile, 'b.md');
      expect(c.fileNames, ['a.md', 'b.md']);
      c.openInFiles('c.md');
      expect((c.pane.value, c.shownFile), ('agent', 'c.md'));
      expect(c.fileNames, ['a.md', 'b.md', 'c.md']);
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

    test('in a row narrower than the least, a tab is as wide as the row, '
        'down to its own least (a chip’s icon and ✕), so none is cut', () {
      expect(fitTabs([150], 70, least: previewChipLeast), [70]);
      expect(fitTabs([150], 40, least: previewChipLeast), [previewChipLeast]);
      expect(fitTabs([150, 150], 70, least: previewChipLeast), [
        70,
        70,
      ], reason: 'two: the row scrolls, each whole');
    });
  });

  test('a label says the folder only when two share a name', () {
    const files = ['docs/plan.md', 'site/plan.md', 'a.md'];
    expect(tabLabel('docs/plan.md', files), 'plan.md · docs');
    expect(tabLabel('a.md', files), 'a.md');
  });

  // A name is anyone's: a bidi override in it shows (docs/security.md), so
  // invoice\u202efdp.sh can't read as invoicehs.pdf.
  const bidi = 'docs/invoice\u202efdp.sh';
  const shown = 'invoice\ufffdfdp.sh';

  test('a label shows a bidi override', () {
    expect(tabLabel(bidi, const [bidi, 'a.md']), shown);
  });

  testWidgets('the one file’s name and its tabs show a bidi override', (
    tester,
  ) async {
    var d = await _app(tester, files: const [bidi]);
    expect(inPane(find.text(shown)), findsOneWidget);
    expect(
      find.byTooltip('/Users/me/nushi/docs/invoice\ufffdfdp.sh'),
      findsOneWidget,
    );
    d.dispose();
    d = await _app(tester, files: const [bidi, 'docs/plan.md']);
    expect(_tab(shown), findsOneWidget);
    expect(find.byTooltip('docs/invoice\ufffdfdp.sh'), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  group('the pane', () {
    testWidgets('one file: its name, plain, its path in a tooltip; no tabs, '
        'no menu', (tester) async {
      final d = await _app(tester, files: _three.take(1).toList());
      expect(find.byType(PaneTabs), findsNothing);
      expect(inPane(find.text('report.md')), findsOneWidget);
      expect(
        find.descendant(
          of: inPane(find.byType(PaneHeader)),
          matching: find.byIcon(Icons.keyboard_arrow_down),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(FilesTopRow),
          matching: find.byType(MenuAnchor),
        ),
        findsNothing,
      );
      expect(find.byTooltip('/Users/me/nushi/docs/report.md'), findsOneWidget);
      d.dispose();
    }, variant: onMac);

    for (final (name, brightness) in [
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      testWidgets('the name wears a control’s ring with the keys on it, and '
          'its tint under the pointer, $name', (tester) async {
        final d = await _app(
          tester,
          brightness: brightness,
          files: _three.take(1).toList(),
        );
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );
        final label = inPane(find.text('report.md'));
        Container box() => tester.widget<Container>(
          find.ancestor(of: label, matching: find.byType(Container)).first,
        );
        expect(box().foregroundDecoration, isNull);
        expect(box().decoration, isNull);
        Focus.of(tester.element(label)).requestFocus();
        await tester.pump(); // the focus moves; the ring is the next frame's
        await tester.pump();
        final t = NushiTheme.of(tester.element(label)).t;
        expect(
          (box().foregroundDecoration! as BoxDecoration).border,
          Border.all(color: t.focus, width: 2),
        );
        final row = inPane(find.byType(PaneHeader));
        await render(tester, row, 'preview_name_focus_$name');
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(label));
        await tester.pump();
        expect((box().decoration! as BoxDecoration).color, t.hover);
        await render(tester, row, 'preview_name_hover_$name');
        d.dispose();
      }, variant: onMac);
    }

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
        final name = tester.getRect(inPane(find.text('report.md')));
        _three.forEach(c.openInFiles);
        c.openInFiles(_three.first);
        await tester.pumpAndSettle();
        expect(find.byType(PaneTabs), findsOneWidget);
        expect(_marks(tester), one);
        // The name it had is the first tab's, to the pixel.
        final first = tester.getRect(inPane(find.text('report.md')));
        expect(first.left, name.left);
        expect(first.center.dy, name.center.dy);
        d.dispose();
      }, variant: onMac);
    }

    testWidgets('each tab leads with its own file’s kind, not the shown '
        'one’s', (tester) async {
      final d = await _app(
        tester,
        files: const ['docs/a.md', 'cmd/b.go', 'site/c.md'],
      );
      d.chats['c']!.openInFiles('cmd/b.go');
      await tester.pumpAndSettle();
      final icons = find.descendant(
        of: find.byType(FilesTopRow),
        matching: find.byType(Icon),
      );
      // The icon nearest the label on its left, in the row.
      IconData? before(String label) {
        final text = tester.getRect(inPane(find.text(label)));
        Rect? best;
        IconData? kind;
        for (final e in icons.evaluate()) {
          final r = tester.getRect(find.byWidget(e.widget));
          if (r.right > text.left || (r.center.dy - text.center.dy).abs() > 2) {
            continue;
          }
          if (best == null || r.right > best.right) {
            best = r;
            kind = (e.widget as Icon).icon;
          }
        }
        return kind;
      }

      expect(before('a.md'), PreviewKind.markdown.icon);
      expect(before('b.go'), PreviewKind.code.icon);
      expect(before('c.md'), PreviewKind.markdown.icon);
      d.dispose();
    }, variant: onMac);

    // The pane lies beside the chat header, its top row level with it (ADR
    // 0123): the two rows share a height and a line, and each row's lines
    // stop on its own border.
    for (final count in [1, 3]) {
      testWidgets('the title row is the header’s height, level with it, '
          '$count open', (tester) async {
        final d = await _app(tester, files: _three.take(count).toList());
        final header = tester.getRect(find.byType(ChatHeader));
        final row = tester.getRect(inPane(find.byType(PaneHeader)));
        expect(header.height, 56);
        expect(row.height, 56);
        expect(row.top, header.top);
        expect(row.bottom, header.bottom);
        expect(header.right, tester.getRect(find.byType(FilesPane)).left);
        final lines = find.descendant(
          of: find.byType(TabFace),
          matching: find.byType(Positioned),
        );
        // With three open, the file showing; the header's switch is a
        // segmented control, with no line (ADR 0111).
        expect(lines, findsNWidgets(count == 1 ? 0 : 1));
        for (final line in lines.evaluate()) {
          final box = line.renderObject! as RenderBox;
          final bottom = box.localToGlobal(box.size.bottomLeft(Offset.zero)).dy;
          expect(bottom, row.bottom - 1);
        }
        d.dispose();
      }, variant: onMac);
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
      d.dispose();
    }, variant: onMac);

    testWidgets('a tab shows its file, and its ✕ closes it', (tester) async {
      final d = await _app(tester, files: _three);
      final c = d.chats['c']!;
      await _tap(tester, inPane(find.text('plan.md')));
      expect(c.shownFile, 'docs/plan.md');
      expect(
        inPane(find.textContaining('Title of plan.md', findRichText: true)),
        findsOneWidget,
      );
      await _tap(tester, _closeOf('plan.md'));
      expect(c.fileNames, ['docs/report.md', 'site/notes.md']);
      expect(c.shownFile, 'site/notes.md');
      await _tap(tester, _closeOf('notes.md'));
      expect(find.byType(PaneTabs), findsNothing, reason: 'one left');
      expect(inPane(find.text('report.md')), findsOneWidget);
      d.dispose();
    }, variant: onMac);

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
    }, variant: onMac);

    testWidgets('the pane’s × hides it and keeps its tabs', (tester) async {
      final d = await _app(tester, files: _three);
      final c = d.chats['c']!;
      await _tap(tester, inPane(find.byTooltip('Close')));
      expect(find.byType(FilesPane), findsNothing);
      expect(c.fileNames, hasLength(3));
      showOrHideFiles(c);
      await tester.pumpAndSettle();
      expect(find.byType(PaneTabs), findsOneWidget);
      expect(c.shownFile, 'docs/report.md');
      d.dispose();
    }, variant: onMac);

    testWidgets('its width is one, across tabs', (tester) async {
      final d = await _app(tester, files: _three);
      paneWidths.value = {'filesPane': 1000};
      await tester.pumpAndSettle();
      double width() => tester.getSize(find.byType(FilesPane)).width;
      expect(width(), 1000);
      await _tap(tester, inPane(find.text('notes.md')));
      expect(width(), 1000);
      await _tap(tester, _closeOf('notes.md'));
      expect(width(), 1000);
      d.dispose();
    }, variant: onMac);

    testWidgets('Source is remembered per file', (tester) async {
      final d = await _app(tester, files: _three);
      Finder source(String name) =>
          inPane(find.textContaining('# Title of $name', findRichText: true));
      await _tap(tester, inPane(find.text('plan.md')));
      await _tap(tester, inPane(find.byType(SourceButton)));
      expect(source('plan.md'), findsOneWidget);
      await _tap(tester, inPane(find.text('report.md')));
      expect(source('report.md'), findsNothing);
      await _tap(tester, inPane(find.text('plan.md')));
      expect(source('plan.md'), findsOneWidget);
      expect(
        tester.widget<SourceButton>(inPane(find.byType(SourceButton))).source,
        isTrue,
      );
      d.dispose();
    }, variant: onMac);

    testWidgets('a file’s view is made again as it shows, one at a time', (
      tester,
    ) async {
      final live = ValueNotifier(0);
      final made = ValueNotifier(0);
      fakeWebViews().newPage = () => _Page(live, made);
      final d = await _app(
        tester,
        files: const ['site/a.html', 'site/b.html'],
        last: true,
      );
      expect(live.value, 1);
      final before = made.value;
      await _tap(tester, inPane(find.text('a.html')));
      await _tap(tester, inPane(find.text('b.html')));
      expect(live.value, 1);
      expect(made.value, before + 2);
      await closeView(tester, d);
    }, variant: onMac);
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
      expect(c.fileNames, ['docs/report.md']);
      await _tap(tester, preview('p'));
      expect(c.fileNames, ['docs/report.md', 'docs/plan.md']);
      expect(find.byType(PaneTabs), findsOneWidget);
      await _tap(tester, preview('r'));
      expect(c.fileNames, hasLength(2));
      expect(c.shownFile, 'docs/report.md');
      d.dispose();
    }, variant: onMac);

    testWidgets('the Files list opens a tab', (tester) async {
      final d = await _app(tester, details: true, width: 2400);
      final c = d.chats['c']!;
      await _tap(
        tester,
        find.descendant(
          of: find.byType(FileRows),
          matching: find.text('plan.md'),
        ),
      );
      expect(c.fileNames, ['docs/plan.md']);
      await _tap(
        tester,
        find.descendant(
          of: find.byType(FileRows),
          matching: find.text('report.md'),
        ),
      );
      expect(c.fileNames, ['docs/plan.md', 'docs/report.md']);
      expect(c.shownFile, 'docs/report.md');
      d.dispose();
    }, variant: onMac);
  });

  group('⌘W', () {
    testWidgets('closes the tab showing; the last leaves the viewer blank, '
        'the pane open', (tester) async {
      final d = await _app(tester, files: _three.take(2).toList());
      final c = d.chats['c']!;
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(c.fileNames, ['docs/plan.md']);
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(find.byType(FileView), findsNothing);
      expect(find.byType(FilesBlank), findsOneWidget);
      expect(filesChats.value, {'c'});
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(c.files.shown.value, isNull);
      expect(find.byType(FilesPane), findsOneWidget);
      d.dispose();
    }, variant: onMac);

    testWidgets('with a file and a browser tab open, closes the one shown '
        "last, then the other; in a pane, that pane's", (tester) async {
      browserFakes();
      final d = await _app(tester, files: _three.take(1).toList());
      final c = d.chats['c']!..openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      final box = find.descendant(
        of: find.byType(Composer),
        matching: find.byType(EditableText),
      );
      // The focus in the box: the kind shown last.
      await _tap(tester, box);
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(c.browser.shown.value, isNull);
      expect(c.fileNames, hasLength(1));
      await _tap(tester, box);
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(c.files.shown.value, isNull);
      // The focus in the file's view: its file, though a page showed last.
      c
        ..openInFiles(_three.first)
        ..openBrowserTab('http://localhost:3000');
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.byType(PreviewBody))).requestFocus();
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(c.files.shown.value, isNull);
      expect(c.browser.shown.value, isNotNull);
      d.dispose();
    }, variant: onMac);

    testWidgets('leaves the files of a hidden Files pane', (tester) async {
      final d = await _app(tester, files: _three.take(2).toList());
      final c = d.chats['c']!;
      showOrHideFiles(c);
      await tester.pumpAndSettle();
      expect(find.byType(FilesPane), findsNothing);
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(c.fileNames, hasLength(2));
      d.dispose();
    }, variant: onMac);

    testWidgets('leaves a preview out of sight', (tester) async {
      final d = await _app(tester, files: _three.take(2).toList());
      final c = d.chats['c']!..tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(c.fileNames, hasLength(2));
      d.dispose();
    }, variant: onMac);

    testWidgets('a focused terminal keeps it', (tester) async {
      terminalChats.value = {'c'};
      final d = await _app(tester, files: _three.take(2).toList());
      await _tap(tester, find.byType(TerminalView));
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(d.chats['c']!.fileNames, hasLength(2));
      d.dispose();
    }, variant: onMac);

    testWidgets('leaves the tab under a dialog; the menu bar’s too', (
      tester,
    ) async {
      final d = await _app(tester, files: _three.take(2).toList());
      final c = d.chats['c']!;
      await press(tester, LogicalKeyboardKey.keyK, cmd: true);
      expect(find.byType(Palette), findsOneWidget);
      await press(tester, LogicalKeyboardKey.keyW, cmd: true);
      expect(c.fileNames, hasLength(2));
      // File › Close Tab, where a ⌘W no widget takes goes (a web page's).
      final navigator = tester.element(find.byType(Navigator).first);
      runAct(navigator, d, Act.closeTab);
      await tester.pumpAndSettle();
      expect(c.fileNames, hasLength(2));
      await press(tester, LogicalKeyboardKey.escape);
      runAct(navigator, d, Act.closeTab);
      await tester.pumpAndSettle();
      expect(c.fileNames, ['docs/plan.md']);
      d.dispose();
    }, variant: onMac);
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
      expect(width('one.md'), lessThan(previewFileTabLeast));
      expect(
        width('five-is-a-rather-longer-name-than-four.md'),
        previewFileTabLeast,
      );
      final rect = tester.getRect(find.byType(PaneTabs));
      final shown = tester.getRect(_tab('eight.md'));
      expect(shown.right, lessThanOrEqualTo(rect.right + 0.5));
      expect(tester.takeException(), isNull);
      // The row doesn't run under the pane's controls.
      expect(
        rect.right,
        lessThanOrEqualTo(tester.getTopLeft(inPane(find.byType(LiveMark))).dx),
      );
      d.dispose();
    }, variant: onMac);

    testWidgets('the pane at its narrowest: nothing overflows or overlaps', (
      tester,
    ) async {
      final d = await _app(tester, files: _three);
      paneWidths.value = {'filesPane': 500};
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FilesPane)).width, 500);
      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(PaneTabs));
      expect(row.width, greaterThan(0));
      expect(
        row.right,
        lessThanOrEqualTo(
          tester.getTopLeft(inPane(find.byType(PaneEndButtons))).dx,
        ),
      );
      d.dispose();
    }, variant: onMac);

    testWidgets('names that fit aren’t cut; those that don’t are', (
      tester,
    ) async {
      final d = await _app(tester, files: _many.take(3).toList());
      // The pane at the width the preview had, its viewer at its least.
      paneWidths.value = {'filesPane': 560};
      await tester.pumpAndSettle();
      bool cut(String label) => tester
          .renderObject<RenderParagraph>(inPane(find.text(label)))
          .didExceedMaxLines;
      expect(_row(tester).maxScrollExtent, lessThan(1), reason: 'they fit');
      expect(cut('release-report-week-of-october-26.md'), isTrue);
      expect(cut('plan.md'), isFalse);
      expect(cut('notes.md'), isFalse);
      d.dispose();
    }, variant: onMac);

    testWidgets('three short names fit the pane as it starts', (tester) async {
      final d = await _app(tester, files: _three);
      for (final name in ['report.md', 'plan.md', 'notes.md']) {
        expect(
          tester
              .renderObject<RenderParagraph>(inPane(find.text(name)).first)
              .didExceedMaxLines,
          isFalse,
          reason: name,
        );
      }
      d.dispose();
    }, variant: onMac);

    testWidgets('picking a tab keeps the row where it is', (tester) async {
      final d = await _app(tester, files: _many, last: true);
      final before = tester.state(find.byType(PaneTabs));
      final at = _row(tester).pixels;
      expect(at, greaterThan(0));
      await _tap(tester, inPane(find.text('seven.md')));
      expect(d.chats['c']!.shownFile, 'docs/seven.md');
      expect(tester.state(find.byType(PaneTabs)), same(before));
      expect(_row(tester).pixels, at);
      d.dispose();
    }, variant: onMac);

    testWidgets('a file opened brings its tab into view', (tester) async {
      final d = await _app(tester, files: _many, last: true);
      final c = d.chats['c']!..openInFiles(_many.first);
      await tester.pumpAndSettle();
      expect(_row(tester).pixels, 0);
      c.openInFiles(_many.last);
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(PaneTabs));
      expect(
        tester.getRect(_tab('eight.md')).right,
        lessThanOrEqualTo(rect.right + 0.5),
      );
      d.dispose();
    }, variant: onMac);

    testWidgets('a wheel scrolls it sideways', (tester) async {
      final d = await _app(tester, files: _many, last: true);
      final row = _row(tester);
      final at = row.pixels;
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(PaneTabs)),
          scrollDelta: const Offset(0, -120),
        ),
      );
      await tester.pumpAndSettle();
      expect(row.pixels, at - 120);
      d.dispose();
    }, variant: onMac);
  });

  group('the window', () {
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
              greaterThan(right - NushiTheme.windowPad - NushiTheme.gutter - 1),
            );
            await render(
              tester,
              find.byType(NushiApp),
              'preview_pane_${count}_${name}_${width.toInt()}',
            );
            d.dispose();
          }, variant: onMac);
        }
      }
    }
  });
}
