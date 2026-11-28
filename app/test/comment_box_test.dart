import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('the box: its button waits for text; ⌘⏎ posts it; a refused '
      'post keeps the text and says why; Esc cancels', (tester) async {
    final posted = <String>[];
    var cancelled = 0;
    var refuse = true;
    await tester.pumpWidget(
      themed(
        CommentBox(
          label: 'Reply',
          autofocus: true,
          onCancel: () => cancelled++,
          onPost: (md) async {
            if (refuse) throw StateError('no');
            posted.add(md);
          },
        ),
        tokens: Tokens.light,
      ),
    );
    Button reply() =>
        tester.widget<Button>(find.widgetWithText(Button, 'Reply'));
    Future<void> commandEnter() async {
      await press(tester, LogicalKeyboardKey.enter, cmd: true);
    }

    expect(reply().onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  Done.  ');
    await tester.pump();
    expect(reply().onPressed, isNotNull);

    await commandEnter();
    expect(posted, isEmpty);
    expect(find.text('Bad state: no'), findsOneWidget);
    expect(find.text('  Done.  '), findsOneWidget); // kept

    refuse = false;
    await commandEnter();
    expect(posted, ['Done.']);
    expect(find.text('Bad state: no'), findsNothing);
    expect(find.text('  Done.  '), findsNothing); // cleared

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(cancelled, 1);
  });

  testWidgets('its button keeps its width while it reads Posting…, so '
      'Cancel beside it stays put', (tester) async {
    final hold = Completer<void>();
    await tester.pumpWidget(
      themed(
        CommentBox(label: 'Reply', onCancel: () {}, onPost: (_) => hold.future),
      ),
    );
    Finder button(String label) =>
        find.byWidgetPredicate((w) => w is Button && w.label == label);
    await tester.enterText(find.byType(TextField), 'Done.');
    await tester.pump();
    final rest = tester.getRect(button('Reply'));
    final cancel = tester.getRect(button('Cancel'));
    await render(tester, find.byType(CommentBox), 'busy_comment_box_idle');
    await tester.tap(button('Reply'));
    await tester.pump();
    expect(tester.getRect(button('Posting…')), rest);
    await render(tester, find.byType(CommentBox), 'busy_comment_box_busy');
    expect(tester.getRect(button('Cancel')), cancel);
    hold.complete();
    await tester.pumpAndSettle();
    expect(tester.getRect(button('Reply')), rest);
  });

  testWidgets('a box left and opened again while its comment posts starts '
      'empty, and gets the text back if the post fails', (tester) async {
    forgetCommentDrafts();
    var posts = 0;
    var hold = Completer<void>();
    Widget box() => themed(
      CommentBox(
        draft: 'jira s A-1',
        onPost: (_) async {
          posts++;
          await hold.future;
        },
      ),
      tokens: Tokens.light,
    );
    Button comment() =>
        tester.widget<Button>(find.widgetWithText(Button, 'Comment'));
    Future<void> leaveAndCome() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(box());
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(box());
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.text('Comment'));
    await tester.pump();
    expect(posts, 1);
    // A look elsewhere, and back, while it posts: nothing to post twice.
    await leaveAndCome();
    expect(find.widgetWithText(TextField, 'Hello'), findsNothing);
    expect(comment().onPressed, isNull);
    hold.complete();
    await tester.pumpAndSettle();
    expect(commentDraft('jira s A-1'), isEmpty);

    // One refused while the box is gone: the text is back for a retry.
    await tester.enterText(find.byType(TextField), 'Again');
    await tester.pump();
    hold = Completer<void>();
    await tester.tap(find.text('Comment'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    hold.completeError(StateError('down'));
    await tester.pump();
    expect(commentDraft('jira s A-1'), 'Again');
    await tester.pumpWidget(box());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Again'), findsOneWidget);
    expect(posts, 2);
  });

  testWidgets('a post refused after a new comment was started in the box '
      'opened again keeps both, and says it failed', (tester) async {
    forgetCommentDrafts();
    final hold = Completer<void>();
    // The app stays; only the box goes and comes back.
    Widget box({bool shown = true}) => themed(
      shown
          ? CommentBox(draft: 'jira s A-2', onPost: (_) => hold.future)
          : const SizedBox(),
      tokens: Tokens.light,
    );

    await tester.pumpWidget(box());
    await tester.enterText(find.byType(TextField), 'Long first comment');
    await tester.pump();
    await tester.tap(find.text('Comment'));
    await tester.pump();
    // Away and back while it posts; a second comment begun meanwhile.
    await tester.pumpWidget(box(shown: false));
    await tester.pumpWidget(box());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump();

    hold.completeError(StateError('down'));
    await tester.pump();
    expect(commentDraft('jira s A-2'), 'Long first comment\n\nsecond');
    expect(
      find.widgetWithText(TextField, 'Long first comment\n\nsecond'),
      findsOneWidget,
    );
    await tester.pump();
    expect(find.textContaining("wasn't posted"), findsOneWidget);
    expect(find.textContaining('Bad state: down'), findsOneWidget);
  });
}
