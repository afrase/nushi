# 0077. Each harness is a concrete type behind small interfaces

## Context
What each agent does beyond ACP was a `chats.Dialect` and more function fields on `chats.Kind`, filled by the table in `knownagents` ([0025](0025-claude-rules-in-one-place.md)). The table had grown to closures and method lists, an agent's behaviour lived partly in it, every call site repeated `c.dialect.X != nil && c.dialect.X(…)`, and nothing wrote down, per agent, what it has. The owner asked for each harness to be a type, with shared code written against interfaces.

## Decision
- **`features/chats/harness.go` declares the interfaces**: `Harness` (`Info()`, plain data in `model.HarnessInfo`) and small optional ones, one per capability or a cohesive group (`Forker`, `ToolReader`, `Transcript`, `Subagents`, `BackgroundTasks`…).
- **Each agent's package has a `Harness` type**, its functions now methods, `Start` among them (`knownagents.Harness` is `chats.Harness` with `Start`, taking `agents.Run`). They meet the interfaces by shape and never import `features/chats`: chats' tests import `internal/claude`. So only `model`, `acp` and plain types are in the signatures.
- **A harness is asked once.** `newKind` asserts each interface and keeps it in a typed field of the service's `kind`, nil when absent; call sites check that field, a group at a time. No type assertion elsewhere in chats. `Meta` is read to its maps there, so `UltracodeMeta`'s nil still says the agent has none.
- **What reads the Mac is a type of its own.** `Local` (`codex.Local`, `ante.Local`, `omp.Local`, `claudehistory.Local`, which lives there since that package needs `claude`) embeds `Harness` and adds `OpenFinder`, `ForkFinder`, `HistoryChecker`, `MessageDater`, and Claude's `HistoryCopier`. `knownagents.Agent` has both; main runs `Local`, the e2e tests `Harness`, which can't reach the owner's files. Codex's `History` stays on `Harness`: it copies nothing and reads nothing.
- **`chats.Kind` is the harness and main's wiring**: `Launch`, `Explain`, `Ready`, `MCP`. `Dialect` is gone.
- **`knownagents/capabilities.go` is the list**, `var _ chats.Forker = claude.Harness{}` a line, since no import would otherwise check a method's signature; a test holds each harness to exactly its list, which the compiler can't.
- **A test double opts in**: `model.HarnessInfo` is itself a harness with nothing beyond ACP, and a test embeds it with one-capability fakes (`fake_test.go`); `testHarness` embeds `claude.Harness`.

## Consequences
- A new agent is a package with a `Harness` and a short row; a new capability is an interface, a `kind` field and its lines in `capabilities.go`.
- `ForkTitle` went into `Transcript` and `Other` and `Default` stayed apart, as a group only holds what every harness in it has: no harness carries a stub to fit one.
- Agent packages now import `features/agents`, for `Run`. It imports neither them nor chats.
- Interfaces take more lines to declare than func fields; the logic in chats and the table take fewer.

## Alternatives considered
- One large `Harness` interface: every agent would stub what it hasn't, and "it has none" would no longer be seen by chats, which offers options by it.
- Agent packages importing chats' types: a cycle with chats' tests, and the wrong way round for a feature that declares what it needs.
- `Local` as a field or an option on `Harness`: a test could then turn it on; as a type, a test has to name it.
