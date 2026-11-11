import 'package:file_selector/file_selector.dart';

/// Nothing outside a browser: tests add to `pastedFiles` themselves.
void watchPastes(void Function(List<XFile> files) f) {}
