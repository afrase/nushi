/// [setMode]: chmod on the Mac; on the web (the phone, which keeps no
/// files) a stub that's never called.
library;

export 'package:nushi/file_mode_web.dart'
    if (dart.library.ffi) 'package:nushi/file_mode_ffi.dart';
