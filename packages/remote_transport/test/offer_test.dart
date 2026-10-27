import 'dart:convert';

import 'package:remote_transport/remote_transport.dart';
import 'package:test/test.dart';

void main() {
  final key = base64Url.encode(List.filled(32, 1)).replaceAll('=', '');
  final secret = base64Url.encode(List.filled(32, 2)).replaceAll('=', '');
  final q =
      'r=${Uri.encodeQueryComponent('wss://nushi.aaronfrase.com')}'
      '&i=abcdefghijklmnopqrstuv&k=$key&s=$secret';

  test('the QR code and the web link read alike', () {
    for (final text in [
      'nushi://pair?$q',
      'https://nushi.aaronfrase.com/#pair?$q',
      '  https://nushi.aaronfrase.com/#pair?$q\n',
    ]) {
      final o = PairingOffer.parse(text);
      expect(o.relay, Uri.parse('wss://nushi.aaronfrase.com'));
      expect(o.id, 'abcdefghijklmnopqrstuv');
      expect(o.key, List.filled(32, 1));
      expect(o.secret, List.filled(32, 2));
    }
  });

  test('anything else is refused', () {
    for (final text in [
      '',
      'hello',
      // The secret in the query would reach the server.
      'https://nushi.aaronfrase.com/?$q',
      'https://nushi.aaronfrase.com/?x=1#pair?$q',
      'nushi://pair?${q.replaceAll(secret, 'short')}',
      'nushi://pair?${q.replaceAll('wss%3A', 'https%3A')}',
      'nushi://other?$q',
    ]) {
      expect(
        () => PairingOffer.parse(text),
        throwsFormatException,
        reason: text,
      );
    }
  });
}
