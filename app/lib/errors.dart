import 'package:connectrpc/connect.dart';

/// What a failed call says, to show: a daemon's error is its message
/// (a `ConnectException`'s own text starts with its code: `[unknown] `).
String errorText(Object e) => switch (e) {
  ConnectException(:final message) => message,
  _ => '$e',
};

/// Whether a call failed because the daemon wasn't there: none answered,
/// or the connection to it was lost (a restart, an update), so the same
/// call is worth making again once it is back (`Daemon.whenBack`).
bool daemonGone(Object e) =>
    e is ConnectException && e.code == Code.unavailable;

/// Whether the daemon refused a call for [reason], as its Nushi-Reason
/// says ('restarting', 'agent_start'); a daemon older than reasons sends
/// none, and [said] reads its message instead.
bool refusedFor(
  ConnectException e,
  String reason,
  bool Function(String message) said,
) => switch (e.metadata['nushi-reason']) {
  final r? => r == reason,
  null => said(e.message),
};
