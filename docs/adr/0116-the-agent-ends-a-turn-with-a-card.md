# 0116. Agent tools are opt-in, and the agent ends a turn with a card of reply buttons

Status: proposed, 2026-11-14; amended the same day with the owner's answers. Builds on [0043](0043-an-mcp-server-of-nushis-own-for-a-chats-tools.md) (Nushi's MCP server) and [0068](0068-an-agent-opens-a-preview.md); amends both: their tools now come only with Agent tools on.

## Context
The owner: "we should be running our own MCP in nushi so agents can control nushi or talk back to it." The trigger is Claude desktop's `ccd_turn` server. Its `wrap_up` tool, called at a turn's end with `{recap, ask, actions: [{label}], blocked}`, shows a card: the recap, a question, a button per action. A tap sends the label as an ordinary user message, an × dismisses the buttons, and the box stays usable. The owner wants the card most on the phone: one tap keeps an agent going while away. He also wants Nushi to add nothing to an agent's context unless the user asks: "without getting any extra parts unless they want it".

Nushi already runs its own MCP server. `nushid tools-mcp` (`internal/mcpserver`) is a stdio server named `nushi` in each session's `mcpServers` (`cmd/nushid/jira.go`'s `mcpTools`, `chats.mcpServers` in `internal/features/chats/agent.go`). It asks the daemon over its Unix socket with a key per chat (`internal/features/tools`). Today it is handed to every Claude and Codex chat (`HarnessInfo.ClientMCP`), unasked. Plans already come through ACP (`plan_view.dart`).

## Decision

**Agent tools, one switch, off at first.** Settings › General › Agent tools ("Give agents Nushi's tools"), kept as `agentTools` (`*bool`, off when absent) in `settings.json`. Under it, a toggle per tool set, each on once the switch is: Preview (`show`, `preview_*`), Jira (the issue tools), End-of-turn cards. The sets turned off are kept as `agentToolsOff` (names). With the switch off, Nushi hands no agent an MCP server, loads no extension, and adds nothing to any system prompt. The one gate is `mcpTools`: `tools.Service.HasTools` answers no, so no server is named. A change marks every running chat `mcpChanged` (`chats.Service.MCPChanged`), so its Reload applies it now. What Nushi adds to an agent's context today, and what the switch covers:

| What | Agents | Covered |
|---|---|---|
| The `nushi` MCP server: `show`, `preview_list/start/stop/logs`, their MCP instructions | Claude, Codex | Yes |
| Jira's `jira_issue`, `jira_comment`, `jira_transitions`, `jira_transition` and their instructions | Claude, Codex, in a chat on an issue | Yes |
| `wrap_up` (below): the MCP set, or Nushi's Pi extension | see coverage | Yes |
| `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` (`claude.Environ`): Claude Code's own task tools, which current models get only with it | Claude | No. Without them Claude sends no plan and the plan view goes dark. They are Claude Code's tools, not Nushi's, and the user's environment can set the variable to 0. Open question 1. |
| `CLAUDE_CODE_REPORT_FINDINGS=1`, `perTaskStopAffordance` (`claude.Harness.Info`'s `SessionMeta`) | Claude | No. They change how `/code-review` reports and what Stop stops. Neither adds anything to the context. |
| `[Nushi]` notes before a prompt: branch renamed or switched, chat moved, a background command stopped, files edited in the preview (`chats/branchnote.go`, `editnote.go`) | all | No. Each tells of something the user did in Nushi that changed the agent's world. Without it the agent works on the wrong branch or folder (docs/facts/claude.md). |
| The Stop prompt for a background task (`claude/subagents.go`) | Claude | No. It is sent only when the user presses Stop. |
| `/context` and title requests | Claude | No. They run in a throwaway fork or a separate model call, outside the chat's context. |

The bridges (`internal/pi`, `internal/ante`) add no text of their own. For existing users this is a behaviour change: `show` and the dev-server tools disappear until they turn Agent tools on. A chat started from a Jira issue gets no Jira tools while it's off, and the new-chat sheet for an issue says so, with a link to the switch (open question 2).

**`wrap_up`, the end-of-turn card.** It is a new `tools.Set` (`internal/features/turn`). Its name and input are Claude desktop's, so what Claude learned there carries over: `recap` (required), `ask`, `actions` (`[{label}]`), `blocked`. It answers at once with fixed text ("Shown to the user. End your turn."). It never waits: the reply comes as the next prompt. It carries `readOnlyHint: true`, `destructiveHint: false`, `openWorldHint: false`: it only shows text. Nushi writes no allow rule (ADR 0007 unchanged). If a harness still asks before every call in its default mode, that agent doesn't get the tool. **No `update_plan`**: a second plan would disagree with ACP's.

**The daemon makes the card.** It checks each call and, if it passes, puts a card item in the chat's transcript right after the call. Clients draw only that item, and the transcript copy (ADR 0047) keeps it. Live, the call comes:
- through the socket for an MCP agent: the key names the chat, and the arguments are the real ones even when the harness hides them (opencode's `execute` script);
- as the ACP `tool_call` of `nushi_wrap_up` for an agent whose tool is Nushi's extension (below), which holds no key.

On a replay, a replayed call's raw input goes through the same check and makes the same card. The `wrap_up` row itself is folded into its card. The limits: `recap` at most 2,000 characters; `ask` at most 300, one paragraph; at most 4 `actions`, each `label` one line of 1 to 80 characters, all different, none starting with `/` or `!`, so a tap can't run a slash command, a skill or a shell escape. Control and bidi characters are dropped from `ask` and labels, and unknown keys are refused (`tools.Decode`). Past a limit, an MCP call fails with fixed text naming the limit, so the agent can fix it. An extension's call is answered before the daemon sees it, so past a limit no card shows.

**Coverage** (anything not seen yet is marked "to check before building"):
- **Claude, Codex**: the MCP set, as today. To check before building: whether `readOnlyHint` lets each run it unasked in the default mode, and whether Codex reads MCP server instructions. If Codex doesn't, it gets the instructions' paragraph through ACP's client system prompt (append mode), where codex-acp advertises it.
- **opencode**: the server with only the sets that need no ask. A set says whether its safety rests on the harness's ask: `show`, `preview_*` and Jira's writes do, `wrap_up` doesn't. `HarnessInfo` gains `ClientMCPUnasked`, set for opencode (its modes ask nothing for MCP tools; ADR 0068's note). The daemon draws the card from the socket call, so Code Mode hiding the input doesn't matter. To check before building: that its models call the tool from `execute`. Old cards come from the transcript copy only, since the replay holds a script.
- **Pi**: the bridge starts each session's pi with Nushi's extension (`--extension <data folder>/agents/extensions/nushi-wrap-up.ts`, written from a copy in nushid). It registers `nushi_wrap_up` with the same input and answers the fixed text. It is named so it can't clash with a user's tool. Nothing in the user's or the folder's settings changes. The bridge reads the call from `tool_execution_start`'s `args`. To check before building: Pi 1.4's flag for one extension, that RPC mode loads it, and that it takes no trust (it isn't the folder's).
- **PiG**: the same extension, when PiG takes the same flag and `node` 22.13 or newer is on the agents' `PATH`. A TypeScript extension needs it, and one that fails to load stops pig at start (docs/facts/pig.md), so without Node a PiG chat gets no card rather than failing. PiG's own mcp extension reads only `<agent dir>/mcp.json` and a trusted folder's `.pig/mcp.json`. A per-chat server there would mean moving the agent folder (sessions, settings, trust) or writing the user's file, so it isn't used. To check before building: the flag, and whether PiG has a per-run MCP config.
- **oh-my-pi**: a Pi fork, so the same extension through the same flag, if `omp --mode acp` takes one. omp ignores MCP configs in ACP mode. Its custom tools otherwise load only from `.omp` and the other folders in the project or in `~/.omp`, which Nushi won't write, so without a flag omp gets none. To check before building: the flag in 18.12.6, and that its ACP `tool_call` carries the input.
- **Ante**: none. Its servers come only from `mcp_servers` in `$ANTE_HOME/settings.json`, and a project's file can't add any (docs/facts/ante.md). A private `ANTE_HOME` moves sessions, logs, skills and MCP sign-ins with it, and Ante has no layering. Copying the user's `settings.json` into one would copy its secrets and drift from what the user changes. Writing the user's file is what Nushi doesn't do for this. It needs Ante to take a server or a tool per session. To check before building: whether 0.3's `ResumeSession.tools` can do that.

**How the agent learns it.** The set's MCP instructions (one short paragraph) and the tool's description, as for `show`. Claude Code puts MCP server instructions in its system prompt. For the extension agents, the description alone. The text is fixed, with no chat content. In short: call it last, after a turn that did work or needs a decision; skip it for a one-line answer; offer 2 to 4 short next steps written as the user would say them; don't repeat the recap in the message; subagents never call it.

**The card.** It sits after the call in the transcript, on `raised` like the findings card (`findings_card.dart`). Top to bottom: the recap as the agent's Markdown (its messages' renderer and link rules), the `ask` in plain text, a button per action, and an × at its corner. On the Mac the buttons are a row of pills; on the phone, full-width buttons stacked above the composer.
- **A tap sends at once.** The label goes through `SendPrompt` as if typed: plain text, nothing attached, no mode change, no marker. The daemon never sends a label itself. A tap leaves a draft alone.
- **The buttons go** on a tap, on any message the user sends, or on the ×, which sends nothing. The recap and question stay as a read-only card. A dismissal is kept with the chat, so every client hides them.
- **Buttons show only** while the card is the chat's last item, no turn runs and nothing is queued. With several calls in a turn, only the last can have buttons. A call inside a subagent's steps makes no card.
- **`blocked: true` makes the chat Needs you**: the amber dot, the Dock badge and a push, until a tap, a message or the ×. The push says "<Agent> needs you" and the chat's id, as a permission's does (`internal/features/remote/push.go`). The recap never goes through a push service, and the Mac's notification doesn't quote it. Only a live call does this. A replayed card never raises Needs you.
- **History**: a replayed chat draws its cards by the same rules. An old chat whose last item is an undismissed card still offers its buttons, since a tap only sends text.
- **Outside Nushi** (`claude --resume`, Codex's terminal, Zed, pi): the server or extension isn't there. Old calls show as an ordinary tool row, and a new call gets the harness's "no such tool". The session stays the agent's (ADR 0008).

**What the agent can't do through it.** It proposes words and nothing else. It can't approve a permission, answer a question card, change a mode, send as the user, or reach another chat.

## Consequences
- Off by default, Nushi costs an agent no context. On, `wrap_up` costs about 300 tokens of definition and instructions a session, and a tool call a turn: its output tokens and one more model round. Claude's MCP tools are deferred, so a session's first call may need a `ToolSearch` (to check before building).
- Claude may over-call it on short answers. Codex's and the Pi family's models may under-call an optional tool. Both are tuned in the instructions' words after recordings, not in code.
- A label is written by an agent that may have read a hostile file or page. The worst it does is put words on a button. The user still taps it, it goes as their message in plain sight, and what it asks for still goes through the harness's permissions. Not running slash commands closes the one path where a tap would act without a turn. `blocked` lets an agent raise Needs you, which a question card already can.
- Pi, PiG and omp run a file Nushi writes, inside their process. It is Nushi's own code, kept 0644 in the data folder, and does nothing but answer.
- The implementation adds docs/security.md entries (the switch, the extension, `wrap_up`), the facts each "to check" settles, "Agent tools" and "End-of-turn card" in the glossary, and the guide's pages.

## Later, not in v1 (each its own decision)
- `set_title` (the chat's title): low risk, but Claude already names sessions, and an injected title could mislead in the sidebar.
- `notify` (a push with no text, rate-limited): otherwise a nuisance channel.
- `open_side_chat`, `start_chat`, or acting on another chat: an agent starting agents spends money and runs code without the user, and moves injected text sideways. High risk.
- Never: answering a permission or question, changing the mode, queueing or sending a message as the user, reading other chats.

## Alternatives considered
- Reading a recap and buttons from the final message's text: it would reach every agent, Ante too, but a misread puts the agent's words on buttons it never meant, and the convention shows as junk in a terminal.
- Drawing the card from the transcript's tool input alone: simpler, but opencode hides it, and the app would repeat the daemon's check.
- A loopback HTTP MCP server: a TCP port any local user can reach where the socket is 0600, and a bearer token in a header.
- An ACP extension method (`_nushi/wrap_up`): the model calls tools, not client methods, so each agent would need to expose it.
- Serving it in-process from `claude-acp-go`, as Claude desktop does: Claude only, and Nushi's UI in a public library.
- Keeping today's tools on by default and switching only `wrap_up`: the owner wants nothing added unasked.

## Open questions for the owner
1. Should Claude's task tools (`CLAUDE_CODE_ENABLE_TODO_TOOLS`) come under Agent tools? It would save their context, but a Claude chat would then show no plan unless the switch is on. I'd keep them out.
2. A chat started from a Jira issue gets no Jira tools while Agent tools is off. Should starting one turn the Jira set on, after a confirmation, or only say so with a link?
