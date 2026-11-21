# 0145. Agents sign in through their own login

Status: accepted, 2026-11-21.

## Context
Codex with no login refuses `session/new` and `session/load` with ACP's Authentication required, through codex-acp as through Nushi's Go agent ([0142](0142-codex-through-nushis-go-agent.md)), and Nushi could only say to run `codex login` in a terminal. ACP has the agent list its ways to sign in in `initialize`'s `authMethods`, and a client call `authenticate` with one: the agent then runs its own login (codex-acp's ChatGPT method opens the browser and waits for the user). Other ACP clients offer that as a Sign in step.

## Decision
- **The agent signs itself in.** `SignInAgent` (API 139) starts a short-lived process of the agent the way a chat's starts (the same launch, so the same program, environment and settings), sends `initialize`, then `authenticate` with the method picked, and stops the process, its group with it, once the agent has answered, the call is cancelled (Cancel, or the app gone), or 10 minutes pass. Nushi never sees a credential and writes nothing of the agent's: the agent's own login stores what it stores. One sign-in per agent at a time: a second is refused while one waits for the user, and one begun while a cancelled one's process still stops waits for it. A Mac-only call: the browser it opens is the Mac's.
- **Only methods the agent runs by itself.** Nushi offers ACP's agent methods only: not a terminal method, not a type it doesn't know (an environment variable's), not one whose `_meta` asks the client for a key or a gateway (codex-acp's `api-key`, `gateway`), and not one the agent's row leaves out (`knownagents`; Codex's `api-key`, `gateway` and `chat-gpt-device-code`, whose page and code the agent shows through a URL elicitation Nushi doesn't take). Nushi never handles the user's keys; a key stays the agent's config or environment.
- **A refused start says how.** It still fails, as the agent start it is (reason `agent_start`), and carries the methods as an `AgentSignIn` detail (`StartChat`, `OpenAgentSession`); a chat whose reopen fails so has a notice of status `reopen_failed` with the methods as its options (an older app, the relay's phone app among them, still offers Try again). With no method Nushi can run, nothing changes: the plain message, with the agent's terminal command where Nushi knows it (`Agent.sign_in`).
- **The app offers it** as a dialog before a new chat and a card in place of a chat's notice, one solid button per method in the agent's words ("Sign in with ChatGPT"), the terminal command beside; signed in, the start is made again, or the chat reopens and a queued message goes. The phone keeps the plain message.

## Consequences
An agent that signs in by itself needs nothing from Nushi; one whose login needs a key, a device code shown by the client or a terminal still signs in in a terminal. Nushi depends on the agent's `authenticate` ending when its login does, and on its login ending with its process.
