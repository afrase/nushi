import 'package:nushi/speller.dart';

/// The app's native edge (ADR 0097): what it asks of the machine it runs
/// on, each capability an interface declared beside what uses it, and a
/// platform's implementations in files of their own (the Mac's are
/// `*_macos.dart`, the only files that may hold platform channels, WebKit's
/// plugin or FFI: `tools/native-edge` checks). main.dart sets [native]
/// once at startup (`macosNative`); each test starts from the same
/// (`flutter_test_config.dart`) and puts a fake in a capability's place.
/// The phone's web app reaches none of it.
class Native {
  new({this.speller});

  /// The spell checker, where there's one (ADR 0083).
  Speller? speller;
}

/// The native edge main.dart chose.
late Native native;
