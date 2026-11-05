// The relay's side of attach_csp_test.dart, in the VM (a hybrid isolate):
// the real nushi-relay serving a web app at the test page's origin, and the
// Content-Security-Policy it sends with the app's page.
import 'dart:async';
import 'dart:io';

import '../e2e_rig.dart';

// The channel is used untyped, as in mac_side.dart.
// ignore_for_file: avoid_dynamic_calls

/// Sends the CSP of the page the relay serves for [origin], then stops the
/// relay once told to; channel is a StreamChannel.
Future<void> hybridMain(dynamic channel, Object? origin) async {
  Rig? built;
  try {
    final rig = built = await Rig.build('nwc');
    await Directory('${rig.path}/web').create();
    await File('${rig.path}/web/index.html').writeAsString('<!doctype html>');
    await rig.startRelay(
      args: ['-web', '${rig.path}/web', '-origin', origin! as String],
    );
    final client = HttpClient();
    final answer = await (await client.getUrl(
      Uri.parse('http://${rig.relayAddress}/'),
    )).close();
    await answer.drain<void>();
    client.close();
    channel.sink.add({'csp': answer.headers.value('content-security-policy')});
    await (channel.stream as Stream<Object?>).first;
    await rig.close();
    channel.sink.add({'done': true});
  } on Object catch (e) {
    channel.sink.add({'error': '$e'});
    await built?.close();
  }
}
