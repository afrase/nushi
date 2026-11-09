import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nushi/app_install.dart';
import 'package:nushi/app_log.dart';

/// Starts [program] in a session of its own, its parent not the app
/// (Process.start's detached mode), with [environment] alone.
typedef Detach = Future<void> Function(
  String program,
  List<String> args,
  Map<String, String> environment,
);

/// Linux's package (ADR 0104): the binary `nushi` with the daemon in
/// `lib/nushid` beside it (where a file manager doesn't show it), the
/// version Flutter writes into `data/flutter_assets/version.json`, the
/// data folder nushid picks itself (ADR 0101). The daemon starts detached
/// with the app's environment, so it has the session's display, Wayland
/// socket and SSH agent, as one the Mac's Launch Services opens has the
/// login's; it stops by the pid the kernel gives for its socket's other
/// end.
class LinuxAppInstall implements AppInstall {
  /// A test passes the [executable] the app runs as, its [environment],
  /// and what [detach]es, [kill]s and where `/proc` is ([proc]).
  new({
    String? executable,
    Map<String, String>? environment,
    this.detach = _detach,
    this.kill = Process.killPid,
    this.proc = '/proc',
  }) : _bundle = File(executable ?? Platform.resolvedExecutable).parent.path,
       _env = environment ?? Platform.environment;

  final String _bundle;
  final Map<String, String> _env;

  /// What starts the daemon.
  final Detach detach;

  /// What sends a pid SIGTERM.
  final bool Function(int pid) kill;

  /// Where the kernel's process files are.
  final String proc;

  /// `$XDG_DATA_HOME/nushi` when that's an absolute path (the spec ignores
  /// a relative one), else `~/.local/share/nushi`: nushid's own rule.
  @override
  String get dataFolder => switch (_env['XDG_DATA_HOME']) {
    final xdg? when xdg.startsWith('/') => '$xdg/nushi',
    _ => '${_env['HOME']}/.local/share/nushi',
  };

  @override
  late final String? daemon = () {
    final path = '$_bundle/lib/nushid';
    return File(path).existsSync() ? path : null;
  }();

  @override
  late final String? daemonBuild = () {
    if (daemon case final path?) {
      final st = File(path).statSync();
      return '${st.size}-${st.modified.millisecondsSinceEpoch}';
    }
    return null;
  }();

  /// The build's `version` and `build_number`, as the Mac's Info.plist
  /// gives them.
  @override
  late final String version = () {
    try {
      final json = jsonDecode(
        File('$_bundle/data/flutter_assets/version.json').readAsStringSync(),
      ) as Map<String, Object?>;
      return '${json['version'] ?? ''}+${json['build_number'] ?? ''}';
    } on Object {
      return '';
    }
  }();

  @override
  String get stopByHand => 'end nushid in the system monitor';

  @override
  Future<void> launch(String dataDir) async {
    final program = daemon;
    if (program == null) return;
    try {
      await detach(program, const ['-login'], launchEnvironment(_env, dataDir));
    } on ProcessException catch (e) {
      appLog.warn("the bundled daemon didn't start", {'error': e.message});
    }
  }

  /// The daemon is the socket's listener: the kernel names its pid
  /// (SO_PEERCRED), which must be a nushid's (`/proc/<pid>/comm`, which
  /// still says nushid after an upgrade replaced its file, where `exe`
  /// would say "(deleted)"), and gets SIGTERM.
  @override
  Future<void> stop(String dataDir) async {
    final pid = await socketPeer('$dataDir/nushid.sock');
    if (pid == null) return;
    final String comm;
    try {
      comm = File('$proc/$pid/comm').readAsStringSync().trim();
    } on FileSystemException {
      return; // gone meanwhile
    }
    if (comm != 'nushid') {
      appLog.warn(
        "the daemon's socket is another program's, so none "
        'stopped',
        {'pid': '$pid', 'program': comm},
      );
      return;
    }
    kill(pid);
  }
}

/// The daemon's environment: the app's, without Nushi's own variables (a
/// `NUSHID_DATA` or token the app inherited), the data folder for
/// `-login` to keep (`NUSHID_DATA`), and the app's `NUSHI_DATA` when it
/// has one (development), which the daemon's dev mode follows, as the
/// Mac's `openHelper` passes it.
Map<String, String> launchEnvironment(Map<String, String> env, String dir) => {
  for (final MapEntry(:key, :value) in env.entries)
    if (!key.startsWith('NUSHI_') && !key.startsWith('NUSHID_')) key: value,
  'NUSHID_DATA': dir,
  'NUSHI_DATA': ?env['NUSHI_DATA'],
};

Future<void> _detach(
  String program,
  List<String> args,
  Map<String, String> environment,
) => Process.start(
  program,
  args,
  environment: environment,
  includeParentEnvironment: false,
  mode: ProcessStartMode.detached,
);

/// The pid of the process listening on the Unix socket at [path], as the
/// kernel tells the other end (`getsockopt(SOL_SOCKET, SO_PEERCRED)`: a
/// `struct ucred`, the pid first; 1 and 17 on x86-64 and arm64), null
/// when nothing answers there.
Future<int?> socketPeer(String path) async {
  final Socket socket;
  try {
    socket = await Socket.connect(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
      timeout: const Duration(seconds: 2),
    );
  } on SocketException {
    return null;
  }
  try {
    final cred = socket.getRawOption(RawSocketOption(1, 17, Uint8List(12)));
    return ByteData.sublistView(cred).getInt32(0, Endian.host);
  } finally {
    socket.destroy();
  }
}
