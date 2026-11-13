import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/native.dart';
import 'package:nushi/palette.dart';

import 'fake_desktop.dart';

// What every test starts with (flutter_test_config.dart's setUp).

void main() {
  test('nothing a test does opens on the desktop', () async {
    expect(native.desktop, isA<FakeDesktop>());
    await native.desktop.reveal('/Users/me/nushi/README.md');
    expect(fakeDesktop(), [
      ['-R', '/Users/me/nushi/README.md'],
    ]);
  });

  test('the next test’s file manager was asked nothing', () {
    expect(fakeDesktop(), isEmpty);
  });

  test('what one test leaves in memory the next doesn’t see', () {
    Collapsible.opened.add('tool-1');
    recentRows.add('chat:c');
  });

  test('…as the one before left it', () {
    expect(Collapsible.opened, isEmpty);
    expect(recentRows, isEmpty);
  });

  test('what lib keeps outside widgets is made through run_state.dart', () {
    // A map, set, list or notifier made at the top level (or static) is
    // held for the whole test process; made by run_state.dart's makers,
    // every test's setUp forgets it. These are kept on purpose.
    const kept = {
      'back_swipe.dart _all', // the swipes mounted now
      'browser_page_macos.dart _commits', // pages' channels, live
      'browser_bar.dart _never', // never changes
      'comment_box.dart commentDraftsChanged', // a count, for saving
      'github_review.dart draftsChanged', // a count, for saving
      'review.dart reviews', // read from disk; forgetReviews
      'run_state.dart _forgets',
      'settings.dart _made', // resetAppSettings
      'syntax.dart _highlighters', // by language, the same for every test
    };
    final made = RegExp(
      r'^(?:final|var|  static final)\b[^=(]*?\b(\w+) = *'
      r'(?:<[^=]*>)?(?:\{\}|\[\]|ValueNotifier\b)',
    );
    final found = <String>{
      for (final f in Directory('lib').listSync().whereType<File>())
        if (f.path.endsWith('.dart'))
          for (final line in f.readAsLinesSync())
            if (made.firstMatch(line) case final m?)
              '${f.uri.pathSegments.last} ${m[1]}',
    };
    expect(found, kept);
  });
}
