import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/trust_card.dart';

void main() {
  testWidgets('the card shows what runs, by file, and waits for a word', (
    tester,
  ) async {
    final ask = TrustAsk('/src/repo', 'Start a chat', [
      FolderRun(
        file: '/src/repo/.mcp.json',
        what: 'MCP server echo',
        command: 'echo hi',
      ),
      FolderRun(
        file: '/src/.mcp.json',
        what: 'MCP server up',
        command: 'up --x',
      ),
      FolderRun(
        file: '/src/repo/.mcp.json',
        what: 'MCP server web',
        command: 'https://e.com',
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(body: TrustCard(ask)),
      ),
    );
    expect(find.text('.mcp.json'), findsOneWidget); // in the folder: relative
    expect(find.text('/src/.mcp.json'), findsOneWidget); // above it: whole
    expect(find.textContaining('echo hi', findRichText: true), findsOneWidget);
    expect(find.textContaining('up --x', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Start anyway'));
    expect(await ask.answer.future, isTrue);
  });
}
