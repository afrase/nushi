import 'package:nushi/native.dart';
import 'package:nushi/speller_macos.dart';

/// The Mac's implementation of each native capability (ADR 0097), each
/// over its Swift side in `macos/Runner`.
Native macosNative() => Native(speller: const MacSpeller());
