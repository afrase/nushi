# 0077. Each harness is a concrete type behind small interfaces

## Context
What each agent does beyond ACP was a `chats.Dialect` and more function fields on `chats.Kind`, filled by the table in `knownagents` ([0025](0025-claude-rules-in-one-place.md)). The table had grown to closures and method lists, an agent's behaviour lived partly in it, every call site repeated `c.dialect.X != nil && c.dialect.X(…)`, and nothing wrote down, per agent, what it has. The owner asked for each harness to be a type, with shared code written against interfaces.

## Decision
- **`features/chats/harness.go` declares the interfaces**: `Harness` (`Info()`, plain data in `model.HarnessInfo`) and small optional ones, one per capability or a cohesive group (`Forker`, `ToolReader`, `Transcript`, `Subagents`, `BackgroundTasks`…).
- **Each agent's package has a `Harness` type**, its functions now methods, `Start` among them (`knownagents.Harness` is `chats.Harness` with `Start`, taking `model.AgentRun`). They meet the interfaces by shape and never import `features/chats`: chats' tests import `internal/claude`. So only `model`, `acp` and plain types are in the signatures.
- **A harness is asked once.** `newKind` asserts each interface and keeps it in a typed field of the service's `kind`, nil when absent; call sites check that field, a group at a time. No type assertion elsewhere in chats.
- **What reads the Mac is a type of its own.** `Local` (`codex.Local`, `ante.Local`, `omp.Local`, `claudehistory.Local`, which lives there since that package needs `claude`) embeds `Harness` and adds `OpenFinder`, `ForkFinder`, `HistoryChecker`, `MessageDater`, and Claude's `WorktreeFinder`. `knownagents.Agent` has both; main runs `Local`, the e2e tests `Harness`, which can't reach the owner's files. Whether a chat can move is `HarnessInfo.Moves`, data rather than a capability, since moving reads nothing of the Mac ([0014](0014-moving-a-chat-forks-it.md)).
- **What is constant is data.** `HarnessInfo` also holds the agent's `_meta` (`InitMeta`, `SessionMeta`, `UltracodeMeta`, whose nil says the agent has none): three getters for maps would be a capability that does nothing.
- **`chats.Kind` is the harness and main's wiring**: `Launch`, `Explain`, `Ready`, `MCP`. `Dialect` is gone.
- **`knownagents/capabilities.go` is the list**, `var _ chats.Forker = claude.Harness{}` a line, since no import would otherwise check a method's signature; a test holds each harness to exactly its list, which the compiler can't.
- **A test double opts in**: `model.HarnessInfo` is itself a harness with nothing beyond ACP, and a test embeds it with one-capability fakes (`fake_test.go`); `testHarness` embeds `claude.Harness`.

## Consequences
- A new agent is a package with a `Harness` and a short row; a new capability is an interface, a `kind` field and its lines in `capabilities.go`.
- `ForkTitle` went into `Transcript` and `Other` and `Default` stayed apart, as a group only holds what every harness in it has: no harness carries a stub to fit one.
- Interfaces take more lines to declare than func fields; the logic in chats and the table take fewer.
- The app goes by what the daemon says, not an agent's name, for what an agent has: `Agent.go_agent` and `Agent.mcp_user_only`, `ListSkillsResponse.has_built_in` and `has_plugins` (asked of the reader, beside `reads_shared`, which also decides who a shared skill can be linked for). Per-agent wording and marks stay keyed by name. While a daemon before API 97 waits to restart (0056), the app goes by those names (`agentFactsApi`), or Ante would offer what it refuses.

## Alternatives considered
- One large `Harness` interface: every agent would stub what it hasn't, and "it has none" would no longer be seen by chats, which offers options by it.
- Agent packages importing chats' types: a cycle with chats' tests, and the wrong way round for a feature that declares what it needs.
- `Local` as a field or an option on `Harness`: a test could then turn it on; as a type, a test has to name it.
