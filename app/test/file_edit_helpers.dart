/// What the preview editor's tests share (ADR 0096): the Mac app on a
/// chat with files on its fake disk, and ways to type and press keys.
library;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/edit_bars.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The chat whose files are edited, and its transcript.
final Chat editChat = chat('c', 'claude', 'Fix the parser');

final editItems = [
  Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Tidy main.go'),
  Item(
    id: 'm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'I tidied the parser in main.go.',
  ),
];

/// A Go file, indented with tabs.
const goSource = 'package main\n\nfunc main() {\n\tprintln("hi")\n}\n';

/// A Go file as gofmt leaves it (tabs to indent), with tabs mid-line too.
const tabbed =
    'package main\n'
    '\n'
    'import "fmt"\n'
    '\n'
    '// point is where a label goes.\n'
    'type point struct {\n'
    '\tx, y\tint    // across\n'
    '\tlabel\tstring // the name\n'
    '}\n'
    '\n'
    'func main() {\n'
    '\tp := point{1, 2, "a"}\n'
    '\tif p.x > 0 {\n'
    '\t\tfmt.Println(p.label)\t// said once\n'
    '\t}\n'
    '}\n';

/// [b]'s sha256, as the daemon gives it.
String sumOf(List<int> b) => sha256.convert(b).toString();

/// The Mac app on that chat ([more] chats beside it), [files] on its
/// fake disk, [open] in the preview.
Future<(Daemon, FakeDaemon)> openEditor(
  WidgetTester tester,
  Map<String, List<int>?> files, {
  List<String> open = const ['main.go'],
  double width = 1700,
  Brightness brightness = Brightness.light,
  List<Chat> more = const [],
}) async {
  viewport(tester, Size(width, 900), brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {};
  final fake = FakeDaemon([editChat, ...more])
    ..answer = ((input) => switch (input) {
      GetChatRequest(chatId: 'c') => GetChatResponse(
        chat: editChat,
        items: editItems,
      ),
      GetChatRequest(:final chatId) => GetChatResponse(
        chat: more.firstWhere((c) => c.id == chatId),
      ),
      _ => null,
    });
  fake.files.addAll(files);
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  open.forEach(d.chats['c']!.openPreview);
  await tester.pumpAndSettle();
  return (d, fake);
}

/// Ends the test: its edits' highlighting timers run out, the app goes.
Future<void> endEditor(WidgetTester tester, Daemon d) async {
  await tester.pump(const Duration(seconds: 1));
  await closeView(tester, d);
}

/// The chat 'c'.
ChatState chatC(Daemon d) => d.chats['c']!;

/// Chat 'c''s edit of [path].
FileEdit editOf(Daemon d, [String path = 'main.go']) => chatC(d).edits[path]!;

/// Types [text] where the editor's cursor is, as its input would.
Future<void> typeIn(WidgetTester tester, FileEdit e, String text) async {
  e.controller.replaceSelection(text);
  await tester.pump();
}

/// Presses ⌘ and [key].
Future<void> cmd(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

/// A tab's unsaved dot.
Finder get unsavedDot => find.byType(UnsavedDot);

/// The Mac's keys.
final onMac = TargetPlatformVariant.only(TargetPlatform.macOS);
