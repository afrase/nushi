import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/path_name.dart';
import 'package:nushi/sidebar_groups.dart' show twinParents;
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'sidebar_fixture.dart';

// Two projects of one name each show their parent as the path it is,
// before the name ("me/cubby", "work/cubby"; "~/kiln" and "/kiln" for a
// home or root parent), so twins are told apart at a glance with no
// separator (issue 119).

/// Two pairs of twins: cubby under me and under work, kiln in the home
/// folder and under the root; and one project of its own.
List<Chat> _twins() {
  final home = Platform.environment['HOME']!;
  return [
    chat('c', 'claude', 'Fold the maps', folder: '/Users/me/cubby'),
    chat('w', 'codex', 'Ship it', folder: '/Users/me/work/cubby', age: 2),
    chat('k', 'claude', 'Fire the glaze', folder: '$home/kiln', age: 4),
    chat('r', 'ante', 'Stack the bricks', folder: '/kiln', age: 6),
    chat('g', 'claude', 'Plant the beds', folder: '/Users/me/garden', age: 8),
  ];
}

/// Three twins whose parents share a name (work), told apart a folder
/// further up; and two lanterns whose parents differ only four folders up.
List<Chat> _deepTwins() => [
  chat(
    'e',
    'claude',
    'Sort the crates',
    folder: '/srv/tenants-east/work/cubby',
  ),
  chat('w', 'codex', 'Count the jars', folder: '/srv/tenants-west/work/cubby'),
  chat(
    'n',
    'ante',
    'Stack the lids',
    folder: '/srv/tenants-north/work/cubby',
    age: 2,
  ),
  chat(
    'a',
    'claude',
    'Trim the wick',
    folder: '/Users/me/src/alder.example/acme/tools/lantern',
    age: 4,
  ),
  chat(
    'b',
    'codex',
    'Wipe the glass',
    folder: '/Users/me/src/birch.example/acme/tools/lantern',
    age: 6,
  ),
];

/// What each [PathName] in view shows, by its name: the parent's text as
/// laid out ('' where none shows), and the name's paragraph.
Map<String, List<(String, RenderParagraph)>> _shown(WidgetTester tester) {
  final out = <String, List<(String, RenderParagraph)>>{};
  for (final e in find.byType(PathName).evaluate()) {
    final w = e.widget as PathName;
    final texts = [
      for (final t
          in find
              .descendant(of: find.byWidget(w), matching: find.byType(Text))
              .evaluate())
        if (t.renderObject case final RenderParagraph p when p.size.width > 0)
          (t.widget as Text).data!,
    ];
    final name = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byWidget(w), matching: find.text(w.name)),
    );
    final parent = texts.length > 1 ? texts.first : '';
    (out[w.name] ??= []).add((parent, name));
  }
  return out;
}

/// Each twin's hint as it shows: never a lone "…" nor one cut from an end
/// (a middle cut keeps both), the name whole, and twins of a name reading
/// apart.
void _expectApart(WidgetTester tester, List<String> names) {
  final shown = _shown(tester);
  for (final name in names) {
    final twins = shown[name]!;
    expect(twins.length, greaterThan(1), reason: name);
    for (final (parent, p) in twins) {
      expect(p.didExceedMaxLines, isFalse, reason: '$name is cut');
      expect(parent, isNot('…'));
      expect(parent, isNot(startsWith('…')), reason: parent);
      expect(parent, isNot(endsWith('…')), reason: parent);
    }
    final parents = [for (final (parent, _) in twins) parent];
    expect(parents.toSet(), hasLength(parents.length), reason: '$parents');
  }
}

void main() {
  setUpAll(loadFonts);

  testWidgets('twins: the parent as a path before the name', (tester) async {
    final (d, _) = await arrangedSidebar(tester, chats: _twins());
    // The parent and the name are two texts side by side.
    for (final parent in ['me/', 'work/', '~/', '/']) {
      expect(find.text(parent), findsOneWidget, reason: parent);
    }
    expect(find.text('cubby'), findsNWidgets(2));
    expect(find.text('kiln'), findsNWidgets(2));
    expect(find.text('garden'), findsOneWidget); // no twin: the name
    d.dispose();
  });

  test('twins whose parents share a name: the trailing folders that tell '
      'each apart', () {
    expect(twinParents([for (final c in _deepTwins()) c.folder]), {
      '/srv/tenants-east/work/cubby': 'tenants-east/work',
      '/srv/tenants-west/work/cubby': 'tenants-west/work',
      '/srv/tenants-north/work/cubby': 'tenants-north/work',
      '/Users/me/src/alder.example/acme/tools/lantern':
          'alder.example/acme/tools',
      '/Users/me/src/birch.example/acme/tools/lantern':
          'birch.example/acme/tools',
    });
  });

  testWidgets('twins whose parents share a name: what tells them apart '
      'shows, cut in its middle where it must, the name whole (issue 119)', (
    tester,
  ) async {
    final (d, _) = await arrangedSidebar(tester, chats: _deepTwins());
    _expectApart(tester, ['cubby', 'lantern']);
    // Each its first folder, which differs, whole.
    expect(
      {for (final (p, _) in _shown(tester)['cubby']!) p},
      {
        for (final side in ['east', 'west', 'north'])
          matches(RegExp('^tenants-$side/(work/|…/)\$')),
      },
    );
    // The lanterns' is cut in its middle: its first folder, which
    // differs, and its end kept.
    final lanterns = {for (final (p, _) in _shown(tester)['lantern']!) p};
    expect(lanterns, {
      matches(RegExp(r'^alder\.example/…/(tools/)?$')),
      matches(RegExp(r'^birch\.example/…/(tools/)?$')),
    });
    d.dispose();
  });

  for (final width in [1700.0, 720.0]) {
    testWidgets('deep twins read apart in the window '
        '(${width.round()})', (tester) async {
      final d = await openApp(
        tester,
        FakeDaemon(_deepTwins()),
        size: Size(width, 900),
      );
      _expectApart(tester, ['cubby', 'lantern']);
      await closeView(tester, d);
    }, variant: onMac);
  }

  for (final b in Brightness.values) {
    final name = b.name;
    testWidgets('golden: two pairs of twins ($name)', (tester) async {
      final (d, _) = await arrangedSidebar(
        tester,
        chats: _twins(),
        tokens: b == Brightness.dark ? Tokens.dark : Tokens.light,
        size: const Size(400, 640),
      );
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/sidebar_twins_$name.png'),
      );
      d.dispose();
    });
  }

  for (final width in [1700.0, 720.0]) {
    for (final b in renderThemes) {
      renderTest('the window with twins (${width.round()}, ${b.name})', (
        tester,
      ) async {
        final d = await openApp(
          tester,
          FakeDaemon(_twins()),
          size: Size(width, 900),
          brightness: b,
        );
        await render(
          tester,
          find.byType(NushiApp),
          'sidebar_twins_${width.round()}_${b.name}',
        );
        await closeView(tester, d);
      }, variant: onMac);
      renderTest('the window with deep twins (${width.round()}, ${b.name})', (
        tester,
      ) async {
        final d = await openApp(
          tester,
          FakeDaemon(_deepTwins()),
          size: Size(width, 900),
          brightness: b,
        );
        await render(
          tester,
          find.byType(NushiApp),
          'sidebar_deep_twins_${width.round()}_${b.name}',
        );
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
