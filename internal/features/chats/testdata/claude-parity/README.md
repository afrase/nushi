# Claude parity scenarios

Each folder is a scenario of `TestClaudeParity` (`../../claude_parity_test.go`): one run of the Node adapter (claude-agent-acp, as Nushi pins it) on the real `claude`, recorded at both ends, which the test replays to Nushi's Go agent (`claudeacp`) to compare what Nushi makes of each.

A scenario is two scripts, written by hand:

- `api.json`: what the model answers. `make claude-record` serves it from a fake Messages API (`claudeagent/claudetest/fakeapi`), so no one's login takes part and every run gets the same answers.
- `client.json`: what Nushi does: the requests it sends the agent, its answers to the agent's requests, and when.

and the recordings `make claude-record` writes from them (never edit them by hand):

- `cli.jsonl`: `claude`'s stdin and stdout, a `claudetest` cassette, written by `claude-tee`; `cli-2.jsonl` and on for each further `claude` the adapter starts in the run (a load, a fork), in the order it starts them;
- `acp-node.jsonl`: the ACP between the client and the adapter, `{"dir":"in"|"out","msg":…}` a line, `"in"` being to the agent;
- `history/`: claude's transcripts (its project folder, the folder's own name and `memory/` left out): `history/1/` and on just before each request that reads them (`session/load`, `resume`, `fork`), `history/end/` once the run is over. The Go agent reads transcripts itself, so the test gives it these at the same points.

A scenario without `cli.jsonl` is skipped by the test until it is recorded. `hello` is still the hand-written recording from before the tools existed; the first `make claude-record` replaces it.

## The scenarios

The scripts are written from what the research and Nushi's facts say claude 2.1.312 and the adapter do; none has run on the real `claude` yet, so the first recording may need a `match` loosened or a `side` turn added (a failed run says which request missed). Scenarios that don't ask about a tool allow it in claude's session settings (`meta`), so only the scenarios about asking ask. `tools/claude-record`'s tests load every scenario, and play those a fake claude can take.

| Scenario | What it does | Also settles |
|---|---|---|
| `hello` | a new session, one prompt | `generate_session_title` |
| `load` | thinking, text and a command; `session/close`; `session/load` (the replay); a prompt after | `tool_use_result` against the hook's `tool_response` |
| `fork` | a fork of the whole session, a prompt on it | |
| `fork-at` | two prompts, a fork at the first answer (`_meta.jetbrains.air.fork`, a rewind), a prompt on it, the old session closed | |
| `list` | `session/list` with a session written and one not | |
| `delete` | `session/delete` of an open session, a list, the delete again 3 s later | the stub claude writes back |
| `permission` | Yes, No, and "don't ask again" on commands, then a command not asked about | |
| `question` | AskUserQuestion with two questions, the second answered with Other | |
| `steering` | a steer while the model answers a command's result | |
| `cancel` | a cancel during a command, then the next prompt (Nushi's own queue) | |
| `cancel-queued` | a prompt queued at the agent while one runs a command, then a cancel | |
| `eof-mid-tool` | the client goes while a command runs | stdin's end during a tool |
| `bash-background` | a background command that ends; claude's turn on its own after | |
| `bash-background-killed` | a background command whose process group Nushi stops (`kill`) | |
| `bash-background-taskstop` | a background command stopped by Claude's `TaskStop` | |
| `subagent-foreground` | a foreground subagent | |
| `subagent-background` | a background subagent that ends; the held turn | `session_state_changed` with background subagents |
| `subagent-stop-taskstop` | a background subagent stopped by `TaskStop` | |
| `subagent-stop-cancel` | a background subagent stopped by `session/cancel` on its session (Nushi's Stop) | |
| `subagent-stop-turn` | a foreground subagent stopped with the turn | |
| `sendmessage` | a message to a finished background subagent, which runs again | |
| `compaction` | `/compact`, then a prompt | |
| `context` | `/context` in a throwaway fork, deleted after, as Nushi asks it | |
| `safeguards` | a refusal: the notice, then claude's retry | |
| `refusal` | a refusal of the retry too: the turn ends `refusal` | |
| `findings` | a `ReportFindings` call | |
| `ultracode` | ultracode on, then an effort change | |
| `models` | `availableModels` in the session's settings | whether `initialize`'s models are filtered |
| `mcp` | a tool of a stdio MCP server (`mcp-echo`), asked about | |

`stop_task` on a background command isn't among them: the adapter never sends it, so a recording through it can't show it.

## Recording

```
env CLAUDE_TEE_REAL=(command -v claude) make claude-record SCENARIOS=all    # or SCENARIOS=hello,permission
```

For each scenario, `tools/claude-record`:

1. serves `api.json` on loopback;
2. runs the adapter (`node`, the adapter set up once in a cache folder from `internal/claude/adapter`'s lockfile) with a throwaway `HOME`, `CLAUDE_CONFIG_DIR` and `TMPDIR`, `ANTHROPIC_BASE_URL` at the fake API, a dummy `ANTHROPIC_API_KEY`, the CLI's calls home off, nothing else of your environment but `PATH`, and `CLAUDE_CODE_EXECUTABLE` at `claude-tee`, which runs `CLAUDE_TEE_REAL`;
3. plays `client.json`;
4. closes the agent's stdin, waits for it to end (then stops its process group), and checks that every turn of `api.json` was asked for, and nothing the scripts don't cover was.

Only a run that went as the scripts say replaces the scenario's recordings. A failed one says why and keeps its folder (the recordings, `agent.log`: the adapter's stderr, `fakeapi.log`: each API call and how it was answered) for a look. Then `claude-tee -schema-diff` reports message kinds and fields the recordings have that claude 2.1.312's schemas don't (`claudeagent/claudetest/cmd/claude-tee/testdata`); it never fails the build.

## `api.json`

```json
{
  "turns": [
    {"match": {"lastUserText": "list the files"},
     "content": [
       {"type": "thinking", "thinking": "I'll look."},
       {"type": "text", "text": "Let me look."},
       {"type": "tool_use", "name": "Bash", "input": {"command": "ls"}}
     ]},
    {"match": {"toolResult": "Bash"}, "content": [{"type": "text", "deltas": ["There are ", "two files."]}]}
  ],
  "side": [],
  "models": ["claude-opus-5-5"],
  "sideText": "Fake title"
}
```

- `turns` answer claude's requests for a reply, **in order, each once**. A request takes the next turn when the turn's `match` fits it; otherwise it is a miss, which fails the recording. A turn streams its `content` as the API does (server-sent events: `message_start`, each block's start, deltas and stop, `message_delta` with the stop reason and usage, `message_stop`).
- `match` (every field given must hold): `lastUserText`, text in the last user message; `toolResult`, a tool (its name, `"*"` for any) whose result the last user message carries; `model`, text in the model's name; `system`, text in the system prompt; `tools`, whether the request has tools; `capture`, values to take from the conversation (below). A turn whose `match` doesn't say `tools` only matches requests with tools, which is to say claude's conversation, not its small requests of its own.
- `capture` names ids only claude knows, a background task's or a subagent's: `{"task": "with ID: (\\w+)"}` takes the first group of the pattern's last match in the request's messages (their text and tool results), and `${task}` in the turn's text, deltas and tool inputs becomes it. A turn whose pattern finds nothing doesn't match.
- A block is `text` (`text`), `thinking` (`thinking`, `signature`) or `tool_use` (`name`, `input`, `id`: one is made up when not given). `deltas` streams it in those pieces; otherwise text and thinking come whole and a tool's input in two halves.
- A turn's other fields: `id` (the message's id, for a fork at it; one is made up when not given), `stop_reason` (default `tool_use` when it has a tool use, else `end_turn`), `stop_details` (a refusal's, as is), `usage` (`input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens`; default: counted), `pauseMs` (a pause before each event, so the client can act mid-stream), `hang` (stop before `message_delta` until claude drops the request: a turn cut short by a cancel), `error` (`{"status": 529, "type": "overloaded_error", "message": "Overloaded"}` instead of a reply).
- `side` turns answer any request they match, as often as it comes, before `turns` are tried: for claude's requests whose number or order the scenario doesn't fix. Their `match` has no implicit `tools`.
- What neither takes and has no tools (or forces a tool): claude's small requests of its own, such as a title, get `sideText` (default "Fake title"), or a forced tool's input made from its schema. `count_tokens` and the models list (`models`) get canned answers. Anything else is a 404, in `fakeapi.log`.

The fake API refuses a key that looks real (`sk-ant-…`) and logs no content.

## `client.json`

```json
{
  "timeout": "60s",
  "steps": [
    {"initialize": {}},
    {"new": "s1"},
    {"prompt": "list the files", "session": "s1", "async": "p1"},
    {"waitFor": {"method": "session/update", "params": {"update": {"sessionUpdate": "tool_call"}}}},
    {"answer": "session/request_permission", "option": "allow_once"},
    {"await": "p1"}
  ]
}
```

Each step has one verb. Requests wait for their answer unless they have `async` (a name `await` waits for later; whatever is never awaited is waited for at the end). An answer that is an error fails the recording unless the step says `"expectError": true`. `timeout` bounds every wait (default a minute).

| Step | Sends |
|---|---|
| `{"initialize": {}}` | `initialize` with Nushi's client capabilities and `_meta` (`internal/claude`); a non-empty object is sent as the params instead |
| `{"new": "s1"}` | `session/new` in the run's folder with Nushi's session `_meta`; names the session `s1` |
| `{"load": "s1"}`, `{"resume": "s1"}` | `session/load`, `session/resume` of the session |
| `{"fork": "s1", "as": "s2"}` | `session/fork`; names the fork |
| `{"list": {}}` | `session/list` in the run's folder |
| `{"close": "s1"}`, `{"delete": "s1"}` | `session/close`, `session/delete` |
| `{"prompt": "text", "session": "s1"}` | `session/prompt` of the text |
| `{"steer": "text", "session": "s1"}` | `_session/steering`, as Nushi steers (`idleBehavior: promptRequired`) |
| `{"cancel": "s1"}` | the `session/cancel` notification |
| `{"request": "method", "params": {…}}` | any request; `"$s1"` in params is that session's id, `"$cwd"` the run's folder |
| `{"notify": "method", "params": {…}}` | any notification, the same way |

`meta` on `new`, `load`, `resume` and `fork` joins Nushi's session `_meta`, objects merged key by key (`{"claudeCode": {"options": {"settings": {"ultracode": true}}}}`). `settings` there is claude's own settings for the session, which the scenarios use to allow the tools they don't ask about (`{"permissions": {"allow": ["Bash"]}}`). `mcpServers` on the same steps is the session's MCP servers as ACP gives them (`[]` when not given); `"$mcp-echo"` in it is `claudetest/cmd/mcp-echo`, a stdio server with one tool, `echo`, which `make claude-record` builds.

| Step | Does |
|---|---|
| `{"answer": "session/request_permission", "option": "allow_once"}` | waits for the agent's next unanswered request of that method and answers it: `option` picks a permission option by its kind or id (`"cancelled"` cancels); `result` answers with that JSON as it is (an `elicitation/create` answer: `{"action": "accept", "content": {…}}`) |
| `{"waitFor": {…}}` | waits for a request or notification from the agent (answers are `await`'s) that has every field given, with the same values (objects field by field), after the one the last `waitFor` found; `"capture": {"c1": "params.update.sessionId"}` names the string at that path in it, as a session is named (a subagent's session, for `{"cancel": "c1"}`) |
| `{"await": "p1"}` | waits for an `async` request's answer |
| `{"kill": "sleep 37"}` | stops the process group below the agent whose command line has the text, as Nushi stops a background command (SIGTERM, then SIGKILL; ADR 0065), once one runs |
| `{"pause": "500ms"}` | waits that long; prefer `waitFor` |
| `{"end": {}}` | ends the script there: the client goes at once (stdin's end), waiting for no answer it hasn't had |

Every request the agent makes must be answered by a step, or the recording fails.
