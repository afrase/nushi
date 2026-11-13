import 'package:nushi/desktop.dart';
import 'package:nushi/native.dart';

/// The file manager as a test has it, in the Mac's place: what it was
/// asked to show, as the Mac's `open` would be told it (`-R` and the path
/// to reveal one, the folder to open it, `-t` and the path as text).
class FakeDesktop implements Desktop {
  /// What it was asked, in order.
  final opened = <List<String>>[];

  @override
  Future<void> reveal(String path) async => opened.add(['-R', path]);

  @override
  Future<void> openFolder(String folder) async => opened.add([folder]);

  @override
  Future<void> openAsText(String path) async => opened.add(['-t', path]);
}

/// What the file manager was asked in this test: every test has a
/// [FakeDesktop] in the Mac's place (`flutter_test_config.dart`).
List<List<String>> fakeDesktop() => (native.desktop as FakeDesktop).opened;
