/// `setMode`, `writeWhole` and `privateDir`: the user's own files on the
/// Mac (chmod); on the web (the phone, which keeps no files) stubs that
/// are never called.
library;

export 'package:nushi/file_mode_web.dart'
    if (dart.library.ffi) 'package:nushi/file_mode_ffi.dart';
