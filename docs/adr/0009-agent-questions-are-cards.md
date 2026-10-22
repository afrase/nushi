# 0009. Agent questions are real, answerable cards

## Context
Claude's AskUserQuestion reaches ACP clients as a form elicitation. Rendering it as text, or answering it automatically, loses the agent's most useful moment of collaboration.

## Decision
An agent question shows as a card: its options, multi-select, an "Other" answer, keyboard navigation. The agent receives exactly what was chosen, nothing more.

## Consequences
- The ACP client must support elicitation requests from day one of Milestone A.
