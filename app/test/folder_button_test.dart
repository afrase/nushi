import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/theme/theme.dart';

import 'dart:io';

import 'fake_daemon.dart';

void main() {
  setUpAll(loadFonts);

  // Stacked (the details panel's Folder): the parent's right edge lines up
  // with the name's, the chevron beside both; a long name is cut.
  for (final (folder, width) in [
    ('$_home/nushi', 300.0),
    ('$_home/a-folder-with-a-very-long-name-indeed', 120.0),
  ]) {
    testWidgets('stacked, $width wide', (tester) async {
      final d = await FakeDaemon([]).connect(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: NushiTheme(Tokens.dark).toThemeData(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: width,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FolderButton(
                    chat: ChatState('c', folder),
                    daemon: d,
                    stacked: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final name = tester.getRect(find.text(folder.split('/').last));
      final parent = tester.getRect(find.text('~'));
      final chevron = tester.getRect(find.byIcon(Icons.expand_more));
      expect(parent.right, name.right);
      expect(chevron.left, greaterThanOrEqualTo(name.right));
      expect(tester.takeException(), isNull); // no overflow
      d.dispose();
    });
  }
}

final _home = Platform.environment['HOME']!;
