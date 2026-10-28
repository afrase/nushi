# 0007. The harness owns permissions; its mode is the only control

## Context
The POC first had a Nushi permission level that mapped onto the agent's mode and answered some prompts itself. In use it was the harness's mode under another name. The user: "Can we just remove permissions from Nushi? This feels like a harness responsibility not ours."

## Decision
- Nushi has no permission level, policy, auto-approval or command gating.
- The agent's own Mode (its `mode` config option, or legacy ACP modes) is the only control, shown once.
- Nushi shows the agent's permission prompts as cards with the agent's own options and never answers one by itself.
- Each agent starts new chats in the mode the user last picked for it; the agent's default until then. A mode change the agent makes on its own is not remembered. (The model and effort are kept the same way since step 391: [0060](0060-a-chat-keeps-its-picks.md).)

## Consequences
- An agent with no full-access mode asks about everything it asks about; the user answers in the chat or configures the harness.

## Alternatives considered
- Keep a Nushi level and show it only where it maps one-to-one: a second vocabulary for the same thing.
