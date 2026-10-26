# Debugging from the logs

Milestone AA's crash test: what the log said for each kind of failure. The short how-to is in `NOTES.md`; what is logged is ADR 0038.

## Debugging from the logs (milestone AA)

`nushid.log` in the data folder (Settings › Logs › Show logs), `nushid.log.1` and `.2` the older ones (10 MB each); `app.log` beside them for what the app wrote while the daemon didn't answer. One chat's story: `grep 'chat=<id>' nushid.log`; a side chat's lines name its chat too. Its agent's processes: `grep 'pid=<pid>'`. A recovered panic's stack is one quoted line: `printf '%b\n' "$(grep panicked nushid.log)"`. ADR 0038 has what is logged and what never is.

The crash test (step 151; the dev daemon on `/tmp/ndaa` with the fake agent, on `/tmp/ndab` with your Claude on Haiku, a release build with a thrown error added for the run and not committed):

| Case | What the log says |
|---|---|
| A killed agent (Claude, `kill -9`) | `level=WARN msg="agent died" chat=43KF… agent=claude folder=/tmp/ndab/repo pid=66779 ran=4.7s signal=SIGKILL`, then `level=ERROR msg="the chat's agent quit unexpectedly" chat=43KF… session=12f704ac-… pid=66779`; the next message: `msg="agent started"`, `msg=session/load … took=738ms`, `msg="chat reopened" … took=896ms` |
| An agent that sends a bad message (the fake's `garbage`) | `level=WARN msg="acp: a line that isn't JSON-RPC" chat=QYOA… pid=66223 bytes=25` (since step 177 acp-go's message, without the decoder's error) and `level=WARN msg="acp: notification failed" … rpc=session/update err="json: cannot unmarshal string into Go value of type …"`; a handler's panic (`acp` test): `level=ERROR msg="acp handler panicked" rpc=session/update panic="…" stack="goroutine 7 [running]:\n…"` |
| A slow `session/load` (the fake with `FAKEAGENT_LOAD_DELAY=7s`) | `level=WARN msg="acp call slow" chat=QYOA… pid=66241 rpc=session/load took=7.003s`, `msg=session/load … took=7.003s`, `msg="chat reopened" … took=7.018s` |
| A Dart exception (release build) | through the daemon: `level=ERROR msg="uncaught error" source=app err="Bad state: crash test: an uncaught error" from=zone stack="#0      main.<anonymous closure>.<anonymous closure> (package:nushi/main.dart:35)\n…"`; Flutter's: `msg="Bad state: …" source=app from=flutter library="crash test" stack=…`; with no daemon, the same lines in `app.log` |
| A daemon panic (`kill -QUIT`, the runtime's crash path; a real `panic` in `logs.TestCrashOutput`, after a rotation) | the runtime's own text in `nushid.log` after the last record: `SIGQUIT: quit`, `PC=… m=0 sigcode=0`, every goroutine's stack (`goroutine 0 gp=… [idle]:` …) |

Found by the run and fixed: `_auth/status_update` (Claude's, an extension Nushi doesn't follow) came as a WARN per notification: now DEBUG ("ignored"); the chat's `session` repeated on the agent's lines: they name the sessions the agent opens instead. Claude's adapter writes its own timings to stderr (`[session/create] … phase=sdk-initialize durationMs=706`), about 20 lines a start, kept: they say where a slow start went.
