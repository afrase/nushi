import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/theme/theme.dart';

/// A daemon that records the pairing answers it gets.
class _Daemon implements Transport {
  final answers = <ConfirmPairingRequest>[];

  @override
  Future<UnaryResponse<I, O>> unary<I extends Object, O extends Object>(
    Spec<I, O> spec,
    I input, [
    CallOptions? options,
  ]) async {
    if (input is ConfirmPairingRequest) answers.add(input);
    return UnaryResponse(spec, Headers(), spec.outputFactory(), Headers());
  }

  @override
  Future<StreamResponse<I, O>> stream<I extends Object, O extends Object>(
    Spec<I, O> spec,
    Stream<I> input, [
    CallOptions? options,
  ]) => throw UnimplementedError();
}

void main() {
  testWidgets("a pairing the Mac didn't start still asks Allow or Deny", (
    tester,
  ) async {
    final daemon = _Daemon();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: const Scaffold(),
      ),
    );
    watchPairings(navigator, NushiServiceClient(daemon));

    remoteState.value = Remote(on: true, pairing: Pairing());
    await tester.pumpAndSettle();
    expect(find.text('Allow'), findsNothing); // no phone yet

    remoteState.value = Remote(
      on: true,
      pairing: Pairing(name: 'Phone', code: '123 456'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pair Phone?'), findsOneWidget);
    expect(find.text('123 456'), findsOneWidget);
    await tester.tap(find.text('Deny'));
    await tester.pumpAndSettle();
    expect(daemon.answers.single.allow, isFalse);
    expect(find.text('Allow'), findsNothing);

    // A pairing that ends before an answer: a new code is the user's call.
    remoteState.value = Remote(
      on: true,
      pairing: Pairing(name: 'Phone', code: '654 321'),
    );
    await tester.pumpAndSettle();
    remoteState.value = Remote(on: true);
    await tester.pumpAndSettle();
    expect(find.text('This code is used up or has expired.'), findsOneWidget);
    expect(find.text('New code'), findsOneWidget);
  });
}
