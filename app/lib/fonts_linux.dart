import 'package:nushi/fonts.dart';

/// Linux's installed fonts, not listed yet: fontconfig's come later (ADR
/// 0102). Until then Settings › Terminal offers the bundled font only.
class LinuxFonts implements Fonts {
  const new();

  @override
  Future<List<String>?> monospaced() async => null;
}
