import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/native.dart';
import 'package:nushi/window_drag_linux.dart';

import 'fake_web_views.dart';

// Pages without the app's own web views (Linux, ADR 0104), as the tests of
// `outside_page.dart` have them. They pair Linux's window and conventions
// with its platform ([linuxOnly]), as a Linux machine runs them.

/// Runs a test as on Linux.
final linuxOnly = TargetPlatformVariant.only(TargetPlatform.linux);

/// The addresses the default browser was sent while the test runs, on
/// Linux's window and conventions without web views, the browser named
/// Firefox; [open] in the fake's place says what opening does.
List<Uri> pagesOutside({Future<void> Function(Uri url)? open}) {
  native
    ..window = const LinuxWindow()
    ..conventions = linuxConventions;
  final opened = <Uri>[];
  fakeWebViews()
    ..embedded = false
    ..open = open ?? ((url) async => opened.add(url))
    ..browserName = (() async => 'Firefox');
  addTearDown(() => defaultBrowser.value = null);
  return opened;
}

/// Answers the runner's `nushi/browser` with [answer] while the test runs,
/// recording the calls.
List<MethodCall> answerBrowser(Object? Function(MethodCall call) answer) {
  const channel = MethodChannel('nushi/browser');
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(channel, (c) async {
          calls.add(c);
          return answer(c);
        });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return calls;
}
