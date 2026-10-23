# Decisions

- [0001](0001-chat-wrangler-and-diff-viewer.md) Nushi is a chat wrangler and a very good diff viewer
- [0002](0002-separate-daemon.md) A separate Go daemon runs the agents; Flutter is the window
- [0003](0003-acp-v1-own-client.md) Agents speak ACP v1 through our own small client
- [0004](0004-connect-over-unix-socket.md) Connect RPC over a Unix socket, additive changes only
- [0005](0005-clients-authenticate.md) Clients authenticate with a token from the start
- [0006](0006-remote-through-relay.md) Remote access later, through an end-to-end encrypted relay (proposed)
- [0007](0007-harness-owns-permissions.md) The harness owns permissions; its mode is the only control
- [0008](0008-chats-belong-to-the-agent.md) Chats belong to the agent
- [0009](0009-agent-questions-are-cards.md) Agent questions are real, answerable cards
- [0010](0010-json-files-for-sessions.md) A JSON file per session until that stops being enough
- [0011](0011-nushi-next-identity.md) The rebuild runs as "Nushi Next" beside the first build
- [0012](0012-diff-view-package.md) The diff viewer uses the published diff_view package
- [0013](0013-app-starts-its-daemon.md) The packaged app starts its own daemon, never stops one on its own
- [0014](0014-moving-a-chat-forks-it.md) Moving a chat forks its Claude session through a copy of Claude's history
- [0015](0015-delete-takes-the-agents-history.md) Deleting a chat deletes the agent's history of it, through ACP
- [0016](0016-a-worktree-per-chat.md) A chat can have a git worktree of its own
