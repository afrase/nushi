// What the daemon says of each agent (internal/e2e/testdata/agents.json,
// which agent_facts_test.go checks against the daemon's ListAgents), for
// FakeDaemon's readyAgents: read from the file on the VM. The browser's
// tests have no file system, and none of them looks at the agents: there
// the fake lists none.
export 'agent_facts_io.dart'
    if (dart.library.js_interop) 'agent_facts_web.dart';
