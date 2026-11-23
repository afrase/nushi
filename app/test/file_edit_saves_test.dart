import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_editor.dart';
import 'package:re_editor/re_editor.dart';

import 'fake_daemon.dart';
import 'file_edit_helpers.dart';
import 'harness.dart';

// When the edits reach the disk, and what a save hears back (ADR 0096):
// Stale replies, the view going, an input method, quitting, pasting and
// tab-indented files.

const _mine = '// mine\n$goSource';

void main() {
  setUpAll(loadFonts);

  testWidgets('a Stale reply after the disk went back to the old text merges '
      'the edits in; a second save writes', (tester) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    await typeIn(tester, e, '// mine\n');
    expect(await e.save(), isTrue);
    // The agent puts the old text back; the watch's message, carrying the
    // sum from before the save, is taken as a late one.
    fake.putFile('main.go', utf8.encode(goSource));
    await tester.pumpAndSettle();
    expect(e.text, _mine);
    // A save over the saved version: Stale, merged.
    e.controller.selection = CodeLineSelection.collapsed(
      index: e.controller.codeLines.length - 1,
      offset: 0,
    );
    await typeIn(tester, e, '// end\n');
    expect(await e.save(), isFalse);
    await tester.pumpAndSettle();
    expect(e.text, '$goSource// end\n');
    expect(e.unsaved, isTrue);
    expect(e.merged, isTrue);
    expect(e.theirs, isNull);
    expect(find.text('Merged a change from disk'), findsOneWidget);
    expect(await e.save(), isTrue);
    expect(fake.writes.last.baseSha256, sumOf(utf8.encode(goSource)));
    expect(utf8.decode(fake.files['main.go']!), '$goSource// end\n');
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a conflict the watch tells of while a save is on its way '
      'stays once the save is answered', (tester) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    await typeIn(tester, e, '// mine\n');
    final held = fake.replyHeld = Completer<void>();
    final saved = e.save();
    await tester.pump();
    expect(fake.writes, hasLength(1));
    // The agent writes over the saved version before the reply comes:
    // the watch tells of a third version, which overlaps the edits.
    const agents = '// theirs\n$goSource';
    fake.putFile('main.go', utf8.encode(agents));
    await tester.pump();
    expect(e.theirs?.text, agents);
    held.complete();
    fake.replyHeld = null;
    expect(await saved, isFalse);
    await tester.pumpAndSettle();
    expect(e.theirs?.text, agents);
    expect(e.unsaved, isTrue);
    expect(find.text('Changed on disk'), findsOneWidget);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets("the save's own version, told by the watch before its reply "
      'while typing goes on on the saved line, is no conflict', (tester) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    await typeIn(tester, e, '// mine\n');
    final held = fake.replyHeld = Completer<void>();
    final saved = e.save();
    await tester.pump();
    // Typing goes on at the end of the line just saved, and the watch
    // tells of the saved version itself before the save's reply.
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 7,
    );
    await typeIn(tester, e, ' more');
    fake.putFile('main.go', utf8.encode(_mine));
    await tester.pump();
    held.complete();
    fake.replyHeld = null;
    expect(await saved, isFalse);
    await tester.pumpAndSettle();
    expect(e.theirs, isNull);
    expect(e.unsaved, isTrue);
    expect(find.text('Changed on disk'), findsNothing);
    expect(await e.save(), isTrue);
    expect(fake.writes.last.baseSha256, sumOf(utf8.encode(_mine)));
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a merge the watch makes while a save is on its way stays '
      'once the save is answered', (tester) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    await typeIn(tester, e, '// mine\n');
    final held = fake.replyHeld = Completer<void>();
    final saved = e.save();
    await tester.pump();
    // The agent adds a line at the end of the saved version.
    const agents = '$_mine// end\n';
    fake.putFile('main.go', utf8.encode(agents));
    await tester.pump();
    held.complete();
    fake.replyHeld = null;
    await saved;
    await tester.pumpAndSettle();
    // The editor holds the disk's text, and knows it does.
    expect(e.text, agents);
    expect(e.unsaved, isFalse);
    expect(e.theirs, isNull);
    await typeIn(tester, e, 'x');
    expect(await e.save(), isTrue);
    expect(fake.writes.last.baseSha256, sumOf(utf8.encode(agents)));
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a Stale reply that overlaps the edits is a conflict', (
    tester,
  ) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    await typeIn(tester, e, '// mine\n');
    expect(await e.save(), isTrue);
    fake.putFile('main.go', utf8.encode(goSource));
    await tester.pumpAndSettle();
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 0,
      offset: 7,
    );
    await typeIn(tester, e, '2');
    expect(await e.save(), isFalse);
    await tester.pumpAndSettle();
    expect(e.theirs?.text, goSource);
    expect(find.text('Changed on disk'), findsOneWidget);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('showing another tab saves; reverted meanwhile, the file shown '
      'again is the disk’s', (tester) async {
    final (d, fake) = await openEditor(
      tester,
      {'main.go': utf8.encode(goSource), 'b.go': utf8.encode('package b\n')},
      open: ['b.go', 'main.go'],
    );
    final e = editOf(d);
    await typeIn(tester, e, '// mine\n');
    chatC(d).openInFiles('b.go');
    await tester.pumpAndSettle();
    expect(fake.writes, hasLength(1));
    expect(utf8.decode(fake.files['main.go']!), _mine);
    // The agent puts it back while it's hidden.
    fake.files['main.go'] = utf8.encode(goSource);
    chatC(d).openInFiles('main.go');
    await tester.pumpAndSettle();
    expect(e.text, goSource);
    expect(e.unsaved, isFalse);
    await typeIn(tester, e, 'x');
    expect(await e.save(), isTrue);
    expect(fake.writes.last.baseSha256, sumOf(utf8.encode(goSource)));
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('picking another chat saves the edits', (tester) async {
    final (d, fake) = await openEditor(
      tester,
      {'main.go': utf8.encode(goSource)},
      more: [chat('o', 'claude', 'Other')],
    );
    await typeIn(tester, editOf(d), '// mine\n');
    d.select('o');
    await tester.pumpAndSettle();
    expect(find.byType(SourceEditor), findsNothing);
    expect(fake.writes, hasLength(1));
    expect(utf8.decode(fake.files['main.go']!), _mine);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('a change from disk waits for an input method to finish', (
    tester,
  ) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    await typeIn(tester, e, 'ni');
    e.controller.composing = const TextRange(start: 0, end: 2);
    expect(e.controller.isComposing, isTrue);
    fake.putFile('main.go', utf8.encode('$goSource// end\n'));
    await tester.pumpAndSettle();
    expect(e.text, 'ni$goSource');
    e.controller.composing = TextRange.empty;
    await tester.pumpAndSettle();
    expect(e.text, 'ni$goSource// end\n');
    expect(e.merged, isTrue);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('quitting with edits that can’t be saved asks; Cancel stays', (
    tester,
  ) async {
    final (d, fake) = await openEditor(tester, {
      'main.go': utf8.encode(goSource),
    });
    final e = editOf(d);
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 3,
      offset: 1,
    );
    await typeIn(tester, e, 'x');
    fake.putFile('main.go', utf8.encode(goSource.replaceAll('println', 'p')));
    await tester.pumpAndSettle();
    expect(e.theirs, isNotNull);
    const codec = JSONMethodCodec();
    final reply = Completer<ByteData?>();
    unawaited(
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/platform',
        codec.encodeMethodCall(const MethodCall('System.requestAppExit')),
        reply.complete,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quit without your changes to main.go?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(codec.decodeEnvelope((await reply.future)!), {'response': 'cancel'});
    expect(chatC(d).edits['main.go'], same(e));
    expect(fake.writes, isEmpty);
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('pasted CR and CRLF line ends are written as the file’s', (
    tester,
  ) async {
    final (d, fake) = await openEditor(
      tester,
      {'notes.txt': utf8.encode('top\n')},
      open: ['notes.txt'],
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': 'a\r\nb\rc'} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final e = editOf(d, 'notes.txt');
    await tester.tap(find.byType(CodeEditor));
    await tester.pump();
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 1,
      offset: 0,
    );
    await press(tester, LogicalKeyboardKey.keyV, cmd: true);
    await press(tester, LogicalKeyboardKey.keyS, cmd: true);
    expect(utf8.decode(fake.writes.single.data), 'top\na\nb\nc');
    await endEditor(tester, d);
  }, variant: onMac);

  testWidgets('in a tab-indented file Return keeps the tabs and Tab is one', (
    tester,
  ) async {
    final (d, _) = await openEditor(tester, {'main.go': utf8.encode(goSource)});
    final e = editOf(d);
    expect(e.tabs, isTrue);
    await tester.tap(find.byType(CodeEditor));
    await tester.pump();
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 3,
      offset: 14,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(e.text.split('\n')[4], '\t\t');
    await press(tester, LogicalKeyboardKey.tab, shift: true, settle: false);
    expect(e.text.split('\n')[4], '\t');
    // Between braces: the closing one on a line of its own, a line a tab
    // further in between.
    await typeIn(tester, e, 'if x {}');
    e.controller.selection = const CodeLineSelection.collapsed(
      index: 4,
      offset: 7,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(e.text.split('\n').sublist(4, 7), ['\tif x {', '\t\t', '\t}']);
    expect(e.controller.selection.extent.offset, 2);
    await endEditor(tester, d);
  }, variant: onMac);

  for (final (indent, size) in [('    ', 4), ('  ', 2)]) {
    testWidgets('in a file indenting with $size spaces Tab steps $size, '
        'whatever the tab size', (tester) async {
      tabSize.value = 8;
      final source = 'def brew(tea):\n${indent}pour(tea)\n\nend\n';
      final (d, _) = await openEditor(
        tester,
        {'brew.py': utf8.encode(source)},
        open: const ['brew.py'],
      );
      final e = editOf(d, 'brew.py');
      expect(e.tabs, isFalse);
      await tester.tap(find.byType(CodeEditor));
      await tester.pump();
      e.controller.selection = const CodeLineSelection.collapsed(
        index: 2,
        offset: 0,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(e.text.split('\n')[2], indent);
      await endEditor(tester, d);
    }, variant: onMac);
  }

  testWidgets('a read-only file shows why', (tester) async {
    final (d, fake) = await openEditor(
      tester,
      {'lock.txt': utf8.encode('a\n')},
      open: ['lock.txt'],
    );
    fake.sendWatch(
      'lock.txt',
      fake.fileNow('lock.txt')
        ..editable = false
        ..readOnly = true,
    );
    await tester.pumpAndSettle();
    expect(chatC(d).edits, isEmpty);
    expect(
      find.text('Read-only: its permissions don’t let you write it.'),
      findsOneWidget,
    );
    for (final b in Brightness.values) {
      for (final width in [1700.0, 720.0]) {
        viewport(tester, Size(width, 900), brightness: b);
        await tester.pumpAndSettle();
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'file_read_only_${width.toInt()}_${b.name}',
        );
      }
    }
    await endEditor(tester, d);
  }, variant: onMac);
}
