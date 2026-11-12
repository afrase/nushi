import 'dart:async';

import 'package:file_selector/file_selector.dart';

/// The files and pictures pasted into the phone's page, which the focused
/// message box attaches (ADR 0091): the browser hands them over with its
/// paste (`phone/paste_web.dart`), where the Mac's ⌘V asks its clipboard
/// (`clipboard_files.dart`). A test adds to it.
final pastedFiles = StreamController<List<XFile>>.broadcast();
