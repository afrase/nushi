import 'package:connectrpc/connect.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:nushi/conventions.dart';
import 'package:nushi/run_state.dart';

/// What a failed call says, to show: a daemon's error is its message
/// (a `ConnectException`'s own text starts with its code: `[unknown] `).
/// On a phone whose daemon is older than its app, a call the daemon
/// doesn't know says how to update it ([updateOnMac]).
String errorText(Object e) => switch (e) {
  ConnectException(code: Code.unimplemented) when phoneDaemonBehind.value =>
    updateOnMac,
  ConnectException(:final message) => message,
  _ => '$e',
};

/// What the phone says of a daemon older than it (ADR 0004): only the
/// paired computer's app updates it ("Open Nushi on your Mac to update its
/// daemon").
String get updateOnMac =>
    'Open Nushi on your ${phoneHost.machine} to update its daemon';

/// Whether the phone's daemon is older than the phone's app, as its last
/// answered ping said: a call it lacks then fails as [updateOnMac]. Never
/// set on the Mac, whose daemon updates with it.
final ValueNotifier<bool> phoneDaemonBehind = runValue(false);

/// Whether a call failed because the daemon wasn't there: none answered,
/// or the connection to it was lost (a restart, an update), so the same
/// call is worth making again once it is back (`Daemon.whenBack`).
bool daemonGone(Object e) =>
    e is ConnectException && e.code == Code.unavailable;

/// Whether the daemon refused a call for [reason], as its Nushi-Reason
/// says ('restarting', 'agent_start', 'changed_since', 'head_moved'):
/// every daemon the app works with sends it (API 91; ADR 0004's floor).
bool refusedFor(ConnectException e, String reason) =>
    e.metadata['nushi-reason'] == reason;
