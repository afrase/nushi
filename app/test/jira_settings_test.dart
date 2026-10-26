import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_settings.dart';
import 'package:nushi/settings_dialog.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

final _now = DateTime(2026, 10, 25, 12);

List<JiraSite> _sites() => [
  JiraSite(
    id: 'acme.atlassian.net',
    url: 'https://acme.atlassian.net',
    email: 'me@acme.com',
    name: 'Test User',
    // "in 5 days" whenever it runs: the dialog reads the clock.
    expires: Int64(
      DateTime.now()
          .add(const Duration(days: 5) - const Duration(hours: 1))
          .millisecondsSinceEpoch,
    ),
  ),
  JiraSite(
    id: 'side.atlassian.net',
    url: 'https://side.atlassian.net',
    email: 'me@side.dev',
    scoped: true,
    needsOk: true,
    problem:
        'the keychain needs your OK for this build of Nushi to read the '
        'token: Settings › Jira',
  ),
];

Future<(FakeDaemon, Daemon)> _open(
  WidgetTester tester, {
  List<JiraSite>? sites,
  Tokens tokens = Tokens.dark,
}) async {
  final fake = FakeDaemon([]);
  var list = sites ?? _sites();
  fake.answer = (input) => switch (input) {
    ListJiraSitesRequest() => ListJiraSitesResponse(sites: list),
    CheckJiraSiteRequest() => CheckJiraSiteResponse(name: 'Test User'),
    AddJiraSiteRequest(:final token) when token != 'good' =>
      throw ConnectException(
        Code.failedPrecondition,
        'Jira refused the email and API token: wrong, revoked or expired',
      ),
    AddJiraSiteRequest() => () {
      final s = JiraSite(id: 'new.atlassian.net', name: 'Test User');
      list = [...list, s];
      return AddJiraSiteResponse(site: s);
    }(),
    _ => null,
  };
  final d = await fake.connect(tester);
  await tester.binding.setSurfaceSize(const Size(640, 640));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showSettings(context, d.client, jira: true),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (fake, d);
}

void main() {
  setUpAll(loadFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        ),
  );

  test('a token close to its end is warned about', () {
    JiraSite inDays(int d) => JiraSite(
      expires: Int64(_now.add(Duration(days: d)).millisecondsSinceEpoch),
    );
    expect(expiryWarning(JiraSite(), _now), isNull);
    expect(expiryWarning(inDays(30), _now), isNull);
    expect(expiryWarning(inDays(5), _now), 'The token expires in 5 days');
    expect(expiryWarning(inDays(1), _now), 'The token expires in 1 day');
    expect(expiryWarning(inDays(-1), _now), 'The token has expired');
  });

  testWidgets('each site with who its token is, or what is wrong', (
    tester,
  ) async {
    final (fake, d) = await _open(tester);
    expect(find.text('acme.atlassian.net'), findsOneWidget);
    expect(find.text('Connected as Test User'), findsOneWidget);
    expect(find.textContaining('The token expires in'), findsOneWidget);
    expect(find.text('me@side.dev · scoped token'), findsOneWidget);
    expect(find.textContaining('needs your OK to read'), findsOneWidget);
    // Only the site that works is checked with Jira.
    expect(fake.calls.whereType<CheckJiraSiteRequest>().map((r) => r.site), [
      'acme.atlassian.net',
    ]);
    await tester.tap(find.text('Allow…'));
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<AllowJiraTokenRequest>().single.site,
      'side.atlassian.net',
    );
    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Remove').last);
    await tester.pumpAndSettle();
    expect(
      fake.calls.whereType<RemoveJiraSiteRequest>().single.site,
      'acme.atlassian.net',
    );
    d.dispose();
  });

  testWidgets('adding a site checks its token', (tester) async {
    final (fake, d) = await _open(tester, sites: []);
    // No site yet: the form is open.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'new.atlassian.net');
    await tester.enterText(fields.at(1), 'me@new.dev');
    await tester.enterText(fields.at(2), 'bad');
    await tester.enterText(fields.at(3), '2027-01-02');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jira refused'), findsOneWidget);
    await tester.enterText(fields.at(2), 'good');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final add = fake.calls.whereType<AddJiraSiteRequest>().last;
    expect(add.url, 'https://new.atlassian.net');
    expect(add.email, 'me@new.dev');
    expect(
      DateTime.fromMillisecondsSinceEpoch(add.expires.toInt()),
      DateTime(2027, 1, 2),
    );
    expect(find.text('new.atlassian.net'), findsOneWidget);
    expect(find.text('Connected as Test User'), findsOneWidget);
    expect(find.text('Add a site'), findsOneWidget);
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, $name', (tester) async {
      final (_, d) = await _open(tester, tokens: tokens);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/jira_settings_$name.png'),
      );
      d.dispose();
    });
  }
}
