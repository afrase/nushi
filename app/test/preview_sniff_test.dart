import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_sniff.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_view.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/syntax_languages.dart';
import 'package:nushi/tree_rows.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _deploy =
    '#!/usr/bin/env bash\n'
    '# Ships the site.\n'
    'set -euo pipefail\n'
    '\n'
    'for host in "\$@"; do\n'
    '  echo "deploying to \$host"\n'
    '  rsync -a dist/ "\$host:/srv/site"\n'
    'done\n';

/// A file with no extension that isn't text: a NUL in its first bytes.
final _blob = [0xCF, 0xFA, 0xED, 0xFE, 0x07, 0x00, 0x00, 0x01, 0x03];

/// The made-up files the fake daemon sends, by path.
final Map<String, List<int>> _files = {
  'scripts/deploy': utf8.encode(_deploy),
  'scripts/blob': _blob,
  '.envrc': utf8.encode('export SITE_ENV=staging\nPATH_add bin\n'),
};

FolderEntry _dir(String name) => FolderEntry(name: name, kind: 'folder');

FolderEntry _file(String name) => FolderEntry(
  name: name,
  kind: 'file',
  size: Int64(600),
  modifiedMs: Int64(
    fixtureNow.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
  ),
);

const _tree = {
  '': ['scripts/', '.DS_Store', '.envrc', 'site.zip'],
  'scripts': ['blob', 'deploy'],
};

Future<Daemon> _app(
  WidgetTester tester, {
  Size size = const Size(1700, 900),
  Brightness? brightness,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {};
  filesChats.value = {'c'};
  filesIgnored.value = false;
  final open = <StreamController<Object>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final c = chat('c', 'claude', 'Ship the site');
  final fake = FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: c),
      _ => null,
    })
    ..streams = (input) {
      if (input is WatchChatFolderRequest) {
        final s = StreamController<WatchChatFolderResponse>();
        open.add(s);
        s.add(
          WatchChatFolderResponse(
            folders: [
              FolderListing(
                path: input.path,
                entries: [
                  for (final n in _tree[input.path] ?? const <String>[])
                    if (n.endsWith('/'))
                      _dir(n.substring(0, n.length - 1))
                    else
                      _file(n),
                ],
              ),
            ],
          ),
        );
        return s.stream;
      }
      if (input is! WatchChatFileRequest) return null;
      final data = _files[input.path] ?? const <int>[];
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        WatchChatFileResponse(
          path: '/Users/me/site/${input.path}',
          data: data,
          size: Int64(data.length),
        ),
      );
      return s.stream;
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Finder _row(String name) => find.ancestor(
  of: find.descendant(of: find.byType(FilesPane), matching: find.text(name)),
  matching: find.byType(TreeRowView),
);

TreeRowView _view(WidgetTester tester, String name) =>
    tester.widget<TreeRowView>(_row(name));

Finder _inPane(Finder f) =>
    find.descendant(of: find.byType(PreviewPane), matching: f);

/// The spans the preview's source shows: more once it is highlighted.
int _spans(WidgetTester tester) {
  var n = 0;
  for (final r in tester.widgetList<RichText>(_inPane(find.byType(RichText)))) {
    r.text.visitChildren((_) {
      n++;
      return true;
    });
  }
  return n;
}

const _note = 'Can’t show this file: it isn’t text.';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  test('what opens, by name: previewKind is sure, the rest opens unless '
      'surely binary', () {
    for (final (path, kind, opens) in [
      ('notes.md', PreviewKind.markdown, true),
      ('cmd/main.go', PreviewKind.code, true),
      ('Makefile', PreviewKind.code, true),
      ('Dockerfile', PreviewKind.code, true),
      // The name doesn't say: the preview reads the bytes.
      ('scripts/deploy', null, true),
      ('bin/release', null, true),
      ('LICENSE', null, true),
      ('CODEOWNERS', null, true),
      ('Procfile', null, true),
      ('.envrc', null, true),
      ('.editorconfig', null, true),
      ('.gitattributes', null, true),
      ('.npmrc', null, true),
      ('.gitignore', null, true),
      ('go.sum', null, true),
      ('notes.unknownext', null, true),
      // Surely binary.
      ('dist/site.zip', null, false),
      ('site.tar.gz', null, false),
      ('Site.DMG', null, false),
      ('lib/libsite.dylib', null, false),
      ('build/main.o', null, false),
      ('fonts/Inter.woff2', null, false),
      ('clip.mov', null, false),
      ('song.mp3', null, false),
      ('data/site.sqlite', null, false),
      ('cache.pyc', null, false),
      ('.DS_Store', null, false),
      ('docs/.DS_Store', null, false),
    ]) {
      expect(previewKind(path), kind, reason: path);
      expect(opensInPreview(path), opens, reason: path);
    }
    // What needs a sure answer still says no.
    expect(isArtifact('scripts/deploy'), isFalse);
  });

  test('isText: no NUL and valid UTF-8 in the first 8 KB', () {
    expect(isText(const []), isTrue);
    expect(isText(utf8.encode(_deploy)), isTrue);
    expect(isText(utf8.encode('naïve café — 日本語 🙂\n')), isTrue);
    expect(isText(_blob), isFalse);
    expect(isText(const [0x66, 0x6F, 0xFF, 0x6F]), isFalse); // not UTF-8
    // A character cut at the 8 KB's end is still text; a NUL past it
    // isn't looked at.
    final cut = [...List.filled(8191, 0x61), ...utf8.encode('é'), 0];
    expect(isText(cut), isTrue);
    expect(isText([...List.filled(100, 0x61), 0]), isFalse);
  });

  test('a script’s language by its #! line, else by its name', () {
    for (final (first, language) in [
      ('#!/bin/bash', 'bash'),
      ('#!/bin/sh -e', 'bash'),
      ('#!/usr/bin/env bash', 'bash'),
      ('#!/usr/bin/env zsh', 'bash'),
      ('#!/usr/local/bin/fish', 'bash'),
      ('#!/usr/bin/env python3', 'python'),
      ('#!/usr/bin/python3.12 -u', 'python'),
      ('#!/usr/bin/env -S uv run --script', 'python'),
      ('#!/usr/bin/env node', 'javascript'),
      ('#!/usr/bin/env -S deno run --allow-net', 'typescript'),
      ('#!/usr/bin/env bun', 'typescript'),
      ('#!/usr/bin/env ruby', 'ruby'),
      ('#!/usr/bin/perl -w', 'perl'),
      ('#!/usr/bin/env php', 'php'),
      ('#!/usr/bin/env lua5.4', 'lua'),
      ('#!/usr/bin/osascript', 'applescript'),
      ('#!/usr/bin/env -i PATH=/bin bash', 'bash'),
      ('#!/usr/bin/env', null),
      ('#!/opt/site/runner', null),
      ('# a comment', null),
    ]) {
      expect(shebangLanguage('$first\necho hi\n'), language, reason: first);
    }
    expect(sourceLanguage('scripts/deploy', _deploy), 'bash');
    expect(sourceLanguage('scripts/deploy', 'plain words\n'), isNull);
    // A name a grammar has, but the #! says otherwise.
    expect(sourceLanguage('scripts/build', '#!/bin/bash\n'), 'bash');
    expect(sourceLanguage('Dockerfile', 'FROM scratch\n'), 'dockerfile');
    expect(sourceLanguage('.envrc', 'export A=1\n'), 'envrc'); // bash's
    expect(sourceLanguage('.npmrc', 'save-exact=true\n'), 'npmrc'); // ini's
    expect(sourceLanguage('.gitignore', 'build/\n'), isNull);
    // An extension decides over the #!.
    expect(sourceLanguage('tool.ts', '#!/usr/bin/env node\n'), 'ts');
  });

  testWidgets('the tree: a script with no extension and a dotfile open as '
      'code, the script highlighted by its #!; a binary with no extension '
      'says so; what is surely binary stays dimmed', (tester) async {
    final d = await _app(tester);
    expect(_view(tester, '.envrc').row.opens, isTrue);
    expect(_view(tester, '.DS_Store').row.opens, isFalse);
    expect(_view(tester, 'site.zip').row.opens, isFalse);
    await tester.tap(_row('scripts'));
    await tester.pumpAndSettle();
    expect(_view(tester, 'deploy').row.opens, isTrue);
    expect(_view(tester, 'blob').row.opens, isTrue);

    await tester.tap(_row('deploy'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.preview.value, 'scripts/deploy');
    expect(_inPane(find.byType(SourceView)), findsOneWidget);
    expect(_inPane(find.byType(WrapButton)), findsOneWidget);
    final plain = _spans(tester);
    await untilReal(tester, () => _spans(tester) > plain + 10);

    await tester.tap(_row('blob'));
    await tester.pumpAndSettle();
    expect(_inPane(find.text(_note)), findsOneWidget);
    expect(_inPane(find.text('Show in Finder')), findsOneWidget);
    expect(_inPane(find.byType(SourceView)), findsNothing);
    expect(_inPane(find.byType(WrapButton)), findsNothing);

    await tester.tap(_row('.envrc'));
    await tester.pumpAndSettle();
    expect(_inPane(find.byType(SourceView)), findsOneWidget);
    expect(
      _inPane(find.textContaining('SITE_ENV', findRichText: true)),
      findsOneWidget,
    );
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    for (final (size, width) in [('wide', 1700.0), ('narrow', 720.0)]) {
      testWidgets('renders: an extensionless script and a binary, $size, '
          '$name', (tester) async {
        final d = await _app(
          tester,
          size: Size(width, 900),
          brightness: brightness,
        );
        await tester.tap(_row('scripts'));
        await tester.pumpAndSettle();
        await tester.tap(_row('deploy'));
        await tester.pumpAndSettle();
        final plain = _spans(tester);
        await untilReal(tester, () => _spans(tester) > plain + 10);
        expect(tester.takeException(), isNull);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'sniff_script_${size}_$name',
        );
        await tester.tap(_row('blob'));
        await tester.pumpAndSettle();
        expect(_inPane(find.text(_note)), findsOneWidget);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'sniff_binary_${size}_$name',
        );
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}
