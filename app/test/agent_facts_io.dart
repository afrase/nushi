import 'dart:convert';
import 'dart:io';

/// Each agent's facts from internal/e2e/testdata/agents.json, in the
/// daemon's order (the tests run in app/).
List<Map<String, Object?>> agentFacts() => [
  for (final a in jsonDecode(
    File('../internal/e2e/testdata/agents.json').readAsStringSync(),
  ) as List)
    a as Map<String, Object?>,
];
