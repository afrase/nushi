import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pull_edit.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/tokens.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';
import 'pull_overview_fixture.dart';

/// Editing a pull request's title and description in place (API 128):
/// the pencils only where GitHub allows it, Save and Cancel, ⌘⏎ and Esc,
/// GitHub's text moved on meanwhile, a draft that outlives a look away.
void main() {
  setUpAll(loadFonts);

  const source =
      'When a session expires mid-request, `RequireSession` loops.\n\n'
      '<!-- the template -->';

  /// acme/lumen#218, which the user may edit unless [canEdit] is false.
  GitHubPull editable({bool canEdit = true, String body = source}) =>
      overviewPull()
        ..canEdit = canEdit
        ..bodySource = body
        ..body = body.split('\n\n').first;

  final description = find.byKey(const ValueKey('description field'));
  final title = find.byKey(const ValueKey('title field'));
  final card = find.byKey(const ValueKey('pull-description'));
  Finder inCard(String text) => find.descendant(
    of: card,
    matching: find.textContaining(text, findRichText: true),
  );
  List<EditGitHubPullRequest> edits(FakeDaemon f) =>
      f.calls.whereType<EditGitHubPullRequest>().toList();

  Future<(Daemon, FakeDaemon)> open(
    WidgetTester tester,
    GitHubPull p, {
    Object? Function(Object input)? more,
    Size size = const Size(1700, 1000),
  }) => openPullTab(tester, p, size: size, more: more);

  testWidgets('the pencils show only when GitHub lets the user edit', (
    tester,
  ) async {
    final (d, _) = await open(tester, editable());
    expect(find.byTooltip('Edit'), findsNWidgets(2)); // title, description
    expect(find.byKey(const ValueKey('edit title')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit description')), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets("no pencils where GitHub doesn't let the user edit", (
    tester,
  ) async {
    final (d, _) = await open(tester, editable(canEdit: false));
    expect(find.byTooltip('Edit'), findsNothing);
    d.dispose();
  }, variant: onMac);

  testWidgets('an empty description says so, with the pencil to add one', (
    tester,
  ) async {
    final (d, _) = await open(tester, editable(body: ''));
    expect(inCard('No description'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit description')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(description).controller!.text, '');
    expect(find.text('Add a description'), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets('Edit opens the source in place; Save sends the description '
      'and what it began from, and the card shows the new text at once', (
    tester,
  ) async {
    final (d, fake) = await open(tester, editable());
    await tester.tap(find.byKey(const ValueKey('edit description')));
    await tester.pumpAndSettle();
    // The source as written, its template comment too.
    expect(tester.widget<TextField>(description).controller!.text, source);
    expect(find.text('Markdown, saves to GitHub as afrase'), findsOneWidget);
    await tester.enterText(description, 'Stops the redirect loop.');
    final reads = fake.calls.whereType<GetGitHubPullRequest>().length;
    await tester.tap(find.text('Save'));
    await tester.pump();
    final e = edits(fake).single;
    expect(e.ref.number, 218);
    expect(e.body, 'Stops the redirect loop.');
    expect(e.hasTitle(), isFalse);
    expect(e.was, source);
    await tester.pumpAndSettle();
    expect(description, findsNothing);
    expect(inCard('Stops the redirect loop.'), findsOneWidget);
    // And the pull request was read again.
    expect(
      fake.calls.whereType<GetGitHubPullRequest>().length,
      greaterThan(reads),
    );
    d.dispose();
  }, variant: onMac);

  testWidgets('Cancel puts the card back; nothing is sent', (tester) async {
    final (d, fake) = await open(tester, editable());
    await tester.tap(find.byKey(const ValueKey('edit description')));
    await tester.pumpAndSettle();
    await tester.enterText(description, 'Half a thought');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(description, findsNothing);
    expect(inCard('When a session expires'), findsOneWidget);
    expect(edits(fake), isEmpty);
    // Opened again, it starts from GitHub's text, not the cancelled one.
    await tester.tap(find.byKey(const ValueKey('edit description')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(description).controller!.text, source);
    d.dispose();
  }, variant: onMac);

  testWidgets('Esc cancels and ⌘⏎ saves', (tester) async {
    final (d, fake) = await open(tester, editable());
    await tester.tap(find.byKey(const ValueKey('edit description')));
    await tester.pumpAndSettle();
    await tester.enterText(description, 'Gone');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(description, findsNothing);
    expect(edits(fake), isEmpty);
    await tester.tap(find.byKey(const ValueKey('edit description')));
    await tester.pumpAndSettle();
    await tester.enterText(description, 'Kept\n\nwith a line');
    // ⏎ alone is a line in the description.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(edits(fake), isEmpty);
    await press(tester, LogicalKeyboardKey.enter, cmd: true);
    expect(edits(fake).single.body, startsWith('Kept\n\nwith a line'));
    d.dispose();
  }, variant: onMac);

  testWidgets('the title: ⏎ saves it, trimmed; Esc cancels', (tester) async {
    final (d, fake) = await open(tester, editable());
    await tester.tap(find.byKey(const ValueKey('edit title')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(title).controller!.text,
      'Fix login redirect loop after session expiry',
    );
    await tester.enterText(title, 'Gone');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(edits(fake), isEmpty);
    await tester.tap(find.byKey(const ValueKey('edit title')));
    await tester.pumpAndSettle();
    await tester.enterText(title, '  Stop the login redirect loop ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final e = edits(fake).single;
    expect(e.title, 'Stop the login redirect loop');
    expect(e.hasBody(), isFalse);
    expect(e.was, 'Fix login redirect loop after session expiry');
    expect(title, findsNothing);
    expect(find.text('Stop the login redirect loop'), findsOneWidget);
    // An empty title isn't sent.
    await tester.tap(find.byKey(const ValueKey('edit title')));
    await tester.pumpAndSettle();
    await tester.enterText(title, '   ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('A pull request needs a title'), findsOneWidget);
    expect(edits(fake), hasLength(1));
    d.dispose();
  }, variant: onMac);

  testWidgets("changed on GitHub since: the editor stays with the user's "
      "text; Show GitHub's version shows it, and Save then goes from it", (
    tester,
  ) async {
    final p = editable();
    var refused = 0;
    final (d, fake) = await open(
      tester,
      p,
      more: (input) {
        if (input is EditGitHubPullRequest && refused == 0) {
          // tomas edited it meanwhile.
          p.bodySource = 'Edited by tomas.';
          refused++;
          throw changedSinceRefusal();
        }
        return null;
      },
    );
    await tester.tap(find.byKey(const ValueKey('edit description')));
    await tester.pumpAndSettle();
    await tester.enterText(description, 'Mine.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(description).controller!.text, 'Mine.');
    expect(
      find.textContaining('it changed on GitHub since you opened it'),
      findsOneWidget,
    );
    await tester.tap(find.text("Show GitHub's version"));
    await tester.pumpAndSettle();
    await render(tester, find.byType(NushiApp), 'pull_edit_changed_since');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('github version')),
        matching: find.text('Edited by tomas.'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // The refused one threw before the fake kept it.
    expect(refused, 1);
    final sent = edits(fake).single;
    expect(sent.was, 'Edited by tomas.');
    expect(sent.body, 'Mine.');
    expect(description, findsNothing);
    d.dispose();
  }, variant: onMac);

  testWidgets('an edit outlives a look at the chat; a poll that brings '
      "another text meanwhile doesn't touch it", (tester) async {
    final p = editable();
    final (d, fake) = await open(tester, p);
    await tester.tap(find.byKey(const ValueKey('edit description')));
    await tester.pumpAndSettle();
    await tester.enterText(description, 'Half written');
    // The chat, and back.
    await tester.tap(find.text('Chat').first);
    await tester.pumpAndSettle();
    expect(description, findsNothing);
    await tester.tap(find.text('Pull request').first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(description).controller!.text,
      'Half written',
    );
    // GitHub's text moves on; the next read brings it.
    p
      ..bodySource = 'Edited by tomas.'
      ..body = 'Edited by tomas.';
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<GetGitHubPullRequest>(), isNotEmpty);
    expect(
      tester.widget<TextField>(description).controller!.text,
      'Half written',
    );
    d.dispose();
  }, variant: onMac);

  for (final width in [1700.0, 720.0]) {
    testWidgets('renders at ${width.toInt()}: the title and the '
        'description being edited', (tester) async {
      sidebarHidden.value = true;
      // Opened wide (narrow, the chat's tabs fold into a menu).
      final (d, _) = await open(tester, editable());
      viewport(tester, Size(width, 1000));
      await tester.pumpAndSettle();
      final name = 'pull_edit_${width.toInt()}';
      await render(tester, find.byType(NushiApp), '${name}_rest');
      await tester.tap(find.byKey(const ValueKey('edit title')));
      await tester.tap(find.byKey(const ValueKey('edit description')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectTextInside(tester, width);
      await render(tester, find.byType(NushiApp), '${name}_editing');
      d.dispose();
    }, variant: onMac);
  }

  testWidgets('Save keeps its width while it reads Saving…, so Cancel '
      'stays put, on the title and on the description', (tester) async {
    var held = Completer<EditGitHubPullResponse>();
    final (d, _) = await open(
      tester,
      editable(),
      more: (input) => input is EditGitHubPullRequest ? held.future : null,
    );
    Finder button(String label) =>
        find.byWidgetPredicate((w) => w is Button && w.label == label);
    for (final (key, field) in [
      ('edit title', title),
      ('edit description', description),
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      await tester.enterText(field, 'Stop the login redirect loop');
      final save = tester.getRect(button('Save'));
      final cancel = tester.getRect(button('Cancel'));
      await tester.tap(button('Save'));
      await tester.pump();
      expect(tester.getRect(button('Saving…')), save, reason: key);
      expect(tester.getRect(button('Cancel')), cancel, reason: key);
      held.complete(EditGitHubPullResponse());
      await tester.pumpAndSettle();
      held = Completer();
    }
    d.dispose();
  }, variant: onMac);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('goldens: the description and the title being edited, '
        '$name', (tester) async {
      final d = await FakeDaemon([]).connect(tester);
      viewport(tester, const Size(820, 280));
      final p = editable();
      await tester.pumpWidget(
        themed(
          tokens: tokens,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              key: const ValueKey('editors'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PullTitle(
                  daemon: d,
                  pull: p,
                  onSaved: () async {},
                  trailing: const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                PullDescription(
                  daemon: d,
                  pull: p,
                  me: 'mira',
                  onSaved: () async {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('editors')),
        matchesGoldenFile('goldens/pull_edit_rest_$name.png'),
      );
      await tester.tap(find.byKey(const ValueKey('edit title')));
      await tester.tap(find.byKey(const ValueKey('edit description')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('editors')),
        matchesGoldenFile('goldens/pull_edit_editing_$name.png'),
      );
      d.dispose();
    });
  }
}
