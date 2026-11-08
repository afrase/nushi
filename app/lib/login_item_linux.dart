import 'package:nushi/login_item.dart';

/// What starts the daemon at login on Linux, none yet: an XDG autostart
/// entry comes later (ADR 0102). Its null state hides Start at login.
class LinuxLoginItem implements LoginItem {
  const new();

  @override
  Future<LoginItemState?> status() async => null;

  @override
  Future<LoginItemState?> set({required bool on}) async => null;

  @override
  Future<LoginItemState?> openSettings() async => null;
}
