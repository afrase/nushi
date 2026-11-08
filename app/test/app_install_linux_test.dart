import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_install_linux.dart';

/// A package laid out as the Linux build makes it, in a temp folder:
/// `nushi`, `lib/nushid` and Flutter's version.json.
Directory _bundle() {
  final dir = Directory.systemTemp.createTempSync('nushi-bundle-');
  addTearDown(() => dir.deleteSync(recursive: true));
  File('${dir.path}/nushi').writeAsStringSync('');
  File('${dir.path}/lib/nushid')
    ..createSync(recursive: true)
    ..writeAsStringSync('daemon');
  File('${dir.path}/data/flutter_assets/version.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      '{"app_name":"nushi","version":"0.30.0","build_number":"1234",'
      '"package_name":"nushi"}',
    );
  return dir;
}

void main() {
  test('the data folder is nushid’s: an absolute XDG_DATA_HOME, else '
      '~/.local/share', () {
    String folder(Map<String, String> env) => LinuxAppInstall(
      executable: '/opt/nushi/nushi',
      environment: env,
    ).dataFolder;
    expect(folder({'HOME': '/home/u'}), '/home/u/.local/share/nushi');
    expect(
      folder({'HOME': '/home/u', 'XDG_DATA_HOME': '/data'}),
      '/data/nushi',
    );
    expect(
      folder({'HOME': '/home/u', 'XDG_DATA_HOME': 'rel'}),
      '/home/u/.local/share/nushi',
    );
  });

  test('a package has lib/nushid, its build and the version Flutter wrote; '
      'a dev build has none', () {
    final dir = _bundle();
    final install = LinuxAppInstall(executable: '${dir.path}/nushi');
    final st = File('${dir.path}/lib/nushid').statSync();
    expect(install.daemon, '${dir.path}/lib/nushid');
    expect(install.daemonBuild, '6-${st.modified.millisecondsSinceEpoch}');
    expect(install.version, '0.30.0+1234');

    final bare = LinuxAppInstall(executable: '${dir.path}/lib/nushi');
    expect((bare.daemon, bare.daemonBuild, bare.version), (null, null, ''));
  });

  test('the daemon starts as `nushid -login`, detached, with the app’s '
      'environment less Nushi’s, and the data folder', () async {
    final dir = _bundle();
    final started = <List<Object>>[];
    LinuxAppInstall install(Map<String, String> env) => LinuxAppInstall(
      executable: '${dir.path}/nushi',
      environment: env,
      detach: (program, args, env) async => started.add([program, args, env]),
    );
    final env = {
      'HOME': '/home/u',
      'DISPLAY': ':0',
      'WAYLAND_DISPLAY': 'wayland-0',
      'SSH_AUTH_SOCK': '/run/user/1000/ssh',
      'NUSHID_DATA': '/elsewhere',
      'NUSHI_TOOLS_KEY': 'k',
    };
    await install(env).launch('/home/u/.local/share/nushi');
    await install({...env, 'NUSHI_DATA': '/tmp/nd'}).launch('/tmp/nd');
    expect(started, [
      [
        '${dir.path}/lib/nushid',
        ['-login'],
        {
          'HOME': '/home/u',
          'DISPLAY': ':0',
          'WAYLAND_DISPLAY': 'wayland-0',
          'SSH_AUTH_SOCK': '/run/user/1000/ssh',
          'NUSHID_DATA': '/home/u/.local/share/nushi',
        },
      ],
      [
        '${dir.path}/lib/nushid',
        ['-login'],
        {
          'HOME': '/home/u',
          'DISPLAY': ':0',
          'WAYLAND_DISPLAY': 'wayland-0',
          'SSH_AUTH_SOCK': '/run/user/1000/ssh',
          'NUSHID_DATA': '/tmp/nd',
          'NUSHI_DATA': '/tmp/nd',
        },
      ],
    ]);
  });

  test('a dev build starts nothing, and a start that fails is logged, not '
      'thrown', () async {
    final dir = _bundle();
    var tries = 0;
    await LinuxAppInstall(
      executable: '${dir.path}/lib/nushi',
      detach: (_, _, _) async => tries++,
    ).launch('/tmp/nd');
    expect(tries, 0);
    await expectLater(
      LinuxAppInstall(
        executable: '${dir.path}/nushi',
        detach: (_, _, _) => throw const ProcessException('nushid', []),
      ).launch('/tmp/nd'),
      completes,
    );
  });

  group('a stop', () {
    late Directory dir;
    late Directory proc;
    late ServerSocket server;
    final killed = <int>[];

    setUp(() async {
      killed.clear();
      dir = Directory.systemTemp.createTempSync('nushi-stop-');
      proc = Directory('${dir.path}/proc');
      server =
          await ServerSocket.bind(
              InternetAddress('${dir.path}/nushid.sock', type: .unix),
              0,
            )
            ..listen((c) => c.destroy());
    });
    tearDown(() async {
      await server.close();
      dir.deleteSync(recursive: true);
    });

    LinuxAppInstall install() => LinuxAppInstall(
      kill: (p) {
        killed.add(p);
        return true;
      },
      proc: proc.path,
    );

    void comm(String name) => File('${proc.path}/$pid/comm')
      ..createSync(recursive: true)
      ..writeAsStringSync('$name\n');

    // The socket's listener is this test's process: the kernel says so.
    test("sends SIGTERM to the socket's listener when it's a nushid", () async {
      expect(await socketPeer('${dir.path}/nushid.sock'), pid);
      comm('nushid');
      await install().stop(dir.path);
      expect(killed, [pid]);
    });

    test("leaves another program's socket, and a gone one, alone", () async {
      comm('dart');
      await install().stop(dir.path);
      File('${proc.path}/$pid/comm').deleteSync();
      await install().stop(dir.path);
      expect(killed, isEmpty);
    });

    test('finds nothing where nothing listens', () async {
      expect(await socketPeer('${dir.path}/none.sock'), isNull);
      await install().stop('${dir.path}/none');
      expect(killed, isEmpty);
    });
  }, skip: Platform.isLinux ? false : "Linux's SO_PEERCRED only");
}
