import 'dart:async';

import 'package:flutter/widgets.dart';

/// A camera scanning for QR codes, in memory: a test says what it sees
/// ([codes]) or why it can't start ([refuse]).
final class Scanner {
  new();

  /// Why [start] fails, if a test wants it to.
  static String? refuse;

  /// What the last scanner saw, for a test to feed.
  static Scanner? last;

  final _codes = StreamController<String>.broadcast();
  bool stopped = false;

  /// The text of each QR code it reads.
  Stream<String> get codes => _codes.stream;

  /// A test's code in front of the camera.
  void see(String text) => _codes.add(text);

  Future<String?> start() async {
    last = this;
    return refuse;
  }

  Widget view() => const ColoredBox(color: Color(0xFF000000));

  void stop() {
    stopped = true;
    unawaited(_codes.close());
  }
}
