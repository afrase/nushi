import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/theme/theme.dart';

/// What a header shows at its start with the sidebar hidden, on the Mac
/// and on Linux alike: the Show-sidebar button past the window's lights
/// (Linux's inset, where it has none), and the chat's [title], when given,
/// at the header's start: after the chat's colour chip when it has a
/// colour ([colored]). One place for every test of the header to
/// check it, so a change to the header's start is made once.
void expectHiddenHeaderStart(
  WidgetTester tester, {
  String? title,
  bool colored = true,
}) {
  expect(
    tester.getRect(find.byType(SidebarButton)).left,
    NushiTheme.windowPad + lightsInset - SidebarButton.reach,
  );
  if (title == null) return;
  expect(
    tester
        .getTopLeft(
          find
              .descendant(
                of: find.byType(ChatHeader),
                matching: find.text(title),
              )
              .first,
        )
        .dx,
    NushiTheme.windowPad +
        hiddenHeaderStart +
        (colored ? ColorChip.width + 8 : 0),
  );
}
