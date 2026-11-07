/// `setMode`, `writeWhole` and `privateDir`: the user's own files on the
/// Mac (libc's chmod through FFI, `file_mode_macos.dart`, ADR 0097); on
/// the web (the phone, which keeps no files) stubs that are never called.
library;

export 'package:nushi/file_mode_web.dart'
    if (dart.library.ffi) 'package:nushi/file_mode_macos.dart';
