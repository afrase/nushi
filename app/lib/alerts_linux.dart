import 'package:nushi/alerts.dart';

/// Linux's notifications and badge, none yet: the freedesktop
/// notification service and the launcher's count come over D-Bus later
/// (ADR 0102). Until then nothing is posted, and Settings shows no
/// permission.
class LinuxAlertCenter implements AlertCenter {
  const new();

  @override
  Future<void> post({
    required String id,
    required String chat,
    required String title,
    required String body,
    required bool sound,
  }) async {}

  @override
  Future<void> withdraw(List<String> ids) async {}

  @override
  Future<void> clear(String chat) async {}

  @override
  Future<void> badge(String label) async {}

  @override
  Future<NotifyPermission?> allowed() async => null;

  @override
  Future<void> openSettings() async {}

  @override
  void onOpen(void Function(String chat)? open) {}
}
